import 'dart:convert';

import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/sso/sso_entry.dart';
import 'package:loginflow_auth/src/core/sso/sso_store.dart';
import 'package:loginflow_auth/src/platform/native/native_channel.dart';
import 'package:loginflow_auth/src/platform/native_sso_options.dart';
import 'package:result_controller/result_controller.dart';

/// [SsoStore] shared with the publisher's other apps: a Keychain access
/// group on Apple platforms, signature-permission ContentProviders on
/// Android (`doc/decisions.md` D12).
final class NativeSsoStore implements SsoStore {
  const NativeSsoStore({required this.options});

  final NativeSsoOptions options;

  @override
  Future<Result<SsoEntry?, LoginFlowError>> read(String issuer) async {
    final raw = await NativeChannel.invokeStorage(
      NativeChannel.ssoRead,
      _arguments(issuer),
    );
    return raw.flatMap((value) {
      if (value == null) {
        return Ok(null);
      }
      try {
        final json = jsonDecode(value);
        if (json is! Map<String, Object?>) {
          return Err(const StorageFailure(description: 'Corrupt SSO entry.'));
        }
        return Ok(SsoEntry.fromJson(json));
      } on FormatException catch (error) {
        return Err(StorageFailure(description: error.message));
      }
    });
  }

  @override
  Future<Result<void, LoginFlowError>> write(SsoEntry entry) async {
    final written = await NativeChannel.invokeStorage(
      NativeChannel.ssoWrite,
      _arguments(
        entry.issuer,
        value: jsonEncode(entry.toJson()),
        updatedAt: entry.updatedAt.millisecondsSinceEpoch,
      ),
    );
    return written.map((_) {});
  }

  @override
  Future<Result<void, LoginFlowError>> delete(String issuer) async {
    final deleted = await NativeChannel.invokeStorage(
      NativeChannel.ssoDelete,
      _arguments(issuer),
    );
    return deleted.map((_) {});
  }

  Map<String, Object?> _arguments(
    String issuer, {
    String? value,
    int? updatedAt,
  }) => <String, Object?>{
    'issuer': issuer,
    'value': ?value,
    'updatedAt': ?updatedAt,
    'accessGroup': ?options.appleAccessGroup,
    'authorities': options.androidSiblingAuthorities,
  };
}
