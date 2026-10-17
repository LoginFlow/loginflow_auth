import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/crypto/base64_url_encoding.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_handle.dart';
import 'package:loginflow_auth/src/core/dpop/dpop_key_store.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/jose/json_web_key.dart' as model;
import 'package:result_controller/result_controller.dart';
import 'package:web/web.dart' as web;

/// [DpopKeyStore] over a non-extractable WebCrypto `CryptoKey`
/// (`SubtleCrypto.generateKey` with `extractable: false`): the private key
/// never leaves the browser's key storage and this library never sees its
/// raw bytes, only signatures `SubtleCrypto.sign` produces.
///
/// A non-extractable `CryptoKey` is structured-cloneable, so it can be put
/// straight into IndexedDB and stays non-extractable when read back — the
/// standard pattern for a DPoP key that must survive a page reload. Without
/// this, a reload would generate a brand new key, and the stored refresh
/// token (bound to the old key's `jkt`) would be rejected by the server on
/// the very next request: not a cosmetic gap, a forced sign-out on every
/// reload. If IndexedDB is unavailable or the stored key cannot be read
/// back (private browsing, a cleared store, a corrupt record), a fresh key
/// is generated instead of failing outright; the existing refresh token no
/// longer matches its `jkt` and the next refresh is rejected by the server,
/// which the library already treats as a normal, explicit sign-out
/// (`SessionRevoked`) rather than a silent failure.
final class WebDpopKeyStore implements DpopKeyStore {
  WebDpopKeyStore({required String clientId}) : _keyId = 'dpop|$clientId';

  static const String _databaseName = 'loginflow_auth_dpop';
  static const String _objectStoreName = 'keys';
  static const int _databaseVersion = 1;

  final String _keyId;
  Future<Result<_WebDpopKeyPair, LoginFlowError>>? _pending;

  @override
  Future<Result<DpopKeyHandle, LoginFlowError>> ensureKey() async {
    final result = await (_pending ??= _loadOrGenerate());
    return result.map(
      (pair) => DpopKeyHandle(keyId: _keyId, publicJwk: pair.publicJwk),
    );
  }

  @override
  Future<Result<String, LoginFlowError>> sign(
    List<int> signingInput, {
    required String keyId,
  }) async {
    final result = await (_pending ??= _loadOrGenerate());
    return result.flatMapAsync((pair) async {
      try {
        final signature = await _sign(pair.privateKey, signingInput);
        return Ok(signature);
      } catch (error) {
        return Err(
          StorageFailure(description: 'WebCrypto signing failed: $error'),
        );
      }
    });
  }

  Future<Result<_WebDpopKeyPair, LoginFlowError>> _loadOrGenerate() async {
    final stored = await _tryLoad();
    if (stored != null) {
      return Ok(stored);
    }
    return _generateAndStore();
  }

  /// `null` on any failure to find or read a usable stored key — the caller
  /// generates a fresh one instead of treating this as fatal.
  Future<_WebDpopKeyPair?> _tryLoad() async {
    try {
      final db = await _openDatabase();
      final transaction = db.transaction(_objectStoreName.toJS, 'readonly');
      final store = transaction.objectStore(_objectStoreName);
      final result = await _await(store.get(_keyId.toJS));
      if (result == null) {
        return null;
      }
      final record = result as _StoredKeyRecord;
      return await _toKeyPair(
        privateKey: record.privateKey,
        publicKey: record.publicKey,
      );
    } catch (error) {
      Log.w('Could not read the stored DPoP key from IndexedDB: $error');
      return null;
    }
  }

  Future<Result<_WebDpopKeyPair, LoginFlowError>> _generateAndStore() async {
    try {
      final subtle = web.window.crypto.subtle;
      final pairAny = await subtle
          .generateKey(
            _EcKeyGenParams(name: 'ECDSA', namedCurve: 'P-256'),
            false,
            <JSString>['sign'.toJS, 'verify'.toJS].toJS,
          )
          .toDart;
      final pair = pairAny as _WebCryptoKeyPair;
      final keyPair = await _toKeyPair(
        privateKey: pair.privateKey,
        publicKey: pair.publicKey,
      );
      await _tryStore(pair);
      return Ok(keyPair);
    } catch (error) {
      return Err(
        StorageFailure(description: 'WebCrypto key generation failed: $error'),
      );
    }
  }

  /// Best-effort: a key that cannot be persisted is still usable for this
  /// page's lifetime, it just will not survive a reload.
  Future<void> _tryStore(_WebCryptoKeyPair pair) async {
    try {
      final db = await _openDatabase();
      final transaction = db.transaction(_objectStoreName.toJS, 'readwrite');
      final store = transaction.objectStore(_objectStoreName);
      store.put(
        _StoredKeyRecord(
          privateKey: pair.privateKey,
          publicKey: pair.publicKey,
        ),
        _keyId.toJS,
      );
      await _awaitTransactionComplete(transaction);
    } catch (error) {
      Log.w('Could not persist the DPoP key in IndexedDB: $error');
    }
  }

  Future<_WebDpopKeyPair> _toKeyPair({
    required web.CryptoKey privateKey,
    required web.CryptoKey publicKey,
  }) async {
    final jwkAny = await web.window.crypto.subtle.exportKey('jwk', publicKey).toDart;
    final jwk = jwkAny as web.JsonWebKey;
    return _WebDpopKeyPair(
      privateKey: privateKey,
      publicJwk: model.JsonWebKey(
        keyType: jwk.kty,
        curve: jwk.crv,
        x: jwk.x,
        y: jwk.y,
      ),
    );
  }

  Future<String> _sign(web.CryptoKey privateKey, List<int> signingInput) async {
    final signatureAny = await web.window.crypto.subtle
        .sign(
          _EcdsaParams(name: 'ECDSA', hash: 'SHA-256'),
          privateKey,
          Uint8List.fromList(signingInput).toJS,
        )
        .toDart;
    final bytes = (signatureAny as JSArrayBuffer).toDart.asUint8List();
    return bytes.toBase64UrlNoPadding();
  }

  Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_databaseName, _databaseVersion);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_objectStoreName)) {
        db.createObjectStore(_objectStoreName);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(request.error ?? 'Unknown IndexedDB error.');
    }).toJS;
    return completer.future;
  }

  Future<JSAny?> _await(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(request.error ?? 'Unknown IndexedDB error.');
    }).toJS;
    return completer.future;
  }

  Future<void> _awaitTransactionComplete(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event _) => completer.complete()).toJS;
    transaction.onerror = ((web.Event _) {
      completer.completeError(transaction.error ?? 'Unknown IndexedDB error.');
    }).toJS;
    return completer.future;
  }
}

class _WebDpopKeyPair {
  const _WebDpopKeyPair({required this.privateKey, required this.publicJwk});

  final web.CryptoKey privateKey;
  final model.JsonWebKey publicJwk;
}

extension type _WebCryptoKeyPair._(JSObject _) implements JSObject {
  external web.CryptoKey get publicKey;
  external web.CryptoKey get privateKey;
}

/// The structured-clone record stored in IndexedDB: both `CryptoKey`
/// objects, the private one still non-extractable after the round trip.
extension type _StoredKeyRecord._(JSObject _) implements JSObject {
  external factory _StoredKeyRecord({
    required web.CryptoKey privateKey,
    required web.CryptoKey publicKey,
  });

  external web.CryptoKey get privateKey;
  external web.CryptoKey get publicKey;
}

extension type _EcKeyGenParams._(JSObject _) implements JSObject {
  external factory _EcKeyGenParams({String name, String namedCurve});
}

extension type _EcdsaParams._(JSObject _) implements JSObject {
  external factory _EcdsaParams({String name, String hash});
}

extension<T> on Result<T, LoginFlowError> {
  Future<Result<R, LoginFlowError>> flatMapAsync<R>(
    Future<Result<R, LoginFlowError>> Function(T value) transform,
  ) => when(ok: transform, err: (error) async => Err(error));
}
