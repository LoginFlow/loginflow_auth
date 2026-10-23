import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/protocol/passkeys/passkey_credential.dart';
import 'package:result_controller/result_controller.dart';

/// LoginFlow's authenticated passkey account-management API
/// (`/v1/user/passkeys/*`): enroll, list, rename, delete.
///
/// Unlike the OAuth/OIDC endpoints, these are not part of
/// `GET /.well-known/openid-configuration` — they are fixed account-API
/// paths, resolved from [issuer] the same way the server itself mounts them
/// (`CLAUDE.md` § API Documentation of `loginflow_api`), not from discovery.
class PasskeyAccountClient {
  const PasskeyAccountClient({required this.transport, required this.issuer});

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri get _collection =>
      issuer.replace(path: '${issuer.path}/v1/user/passkeys');

  Uri _credential(String id) =>
      _collection.replace(path: '${_collection.path}/$id');

  /// `POST /v1/user/passkeys/enroll/start`. Returns `webauthn-rs`'s
  /// `CreationChallengeResponse`, unmodified — pass it straight to
  /// `PasskeyAuthenticator.createCredential`.
  Future<Result<Map<String, Object?>, LoginFlowError>> startEnroll({
    required String bearerToken,
    required String username,
    required String displayName,
  }) async {
    final reply = await transport.postJson(
      _collection.replace(path: '${_collection.path}/enroll/start'),
      <String, Object?>{'username': username, 'display_name': displayName},
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeObject()
          : Err(reply.toAccountApiError()),
    );
  }

  /// `POST /v1/user/passkeys/enroll/finish`. [credential] is the raw
  /// `PublicKeyCredential` JSON from `PasskeyAuthenticator.createCredential`.
  Future<Result<PasskeyCredential, LoginFlowError>> finishEnroll({
    required String bearerToken,
    required Map<String, Object?> credential,
    String? name,
  }) async {
    final reply = await transport.postJson(
      _collection.replace(path: '${_collection.path}/enroll/finish'),
      <String, Object?>{'credential': credential, 'name': ?name},
      bearerToken: bearerToken,
    );
    return reply.flatMap(_toCredential);
  }

  /// `GET /v1/user/passkeys`.
  Future<Result<List<PasskeyCredential>, LoginFlowError>> list({
    required String bearerToken,
  }) async {
    final reply = await transport.getJson(
      _collection,
      bearerToken: bearerToken,
    );
    return reply.flatMap((reply) {
      if (!reply.isSuccess) {
        return Err(reply.toAccountApiError());
      }
      return reply.envelopeList().flatMap((items) {
        try {
          return Ok(items.map(PasskeyCredential.fromJson).toList());
        } on FormatException catch (error) {
          return Err(
            ServerResponseInvalid(
              statusCode: reply.statusCode,
              description: error.message,
            ),
          );
        }
      });
    });
  }

  /// `PATCH /v1/user/passkeys/{id}`.
  Future<Result<PasskeyCredential, LoginFlowError>> rename({
    required String bearerToken,
    required String id,
    required String name,
  }) async {
    final reply = await transport.patchJson(_credential(id), <String, Object?>{
      'name': name,
    }, bearerToken: bearerToken);
    return reply.flatMap(_toCredential);
  }

  /// `DELETE /v1/user/passkeys/{id}`.
  Future<Result<void, LoginFlowError>> delete({
    required String bearerToken,
    required String id,
  }) async {
    final reply = await transport.deleteJson(
      _credential(id),
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess ? Ok(null) : Err(reply.toAccountApiError()),
    );
  }

  Result<PasskeyCredential, LoginFlowError> _toCredential(
    TransportReply reply,
  ) {
    if (!reply.isSuccess) {
      return Err(reply.toAccountApiError());
    }
    return reply.envelopeObject().flatMap((json) {
      try {
        return Ok(PasskeyCredential.fromJson(json));
      } on FormatException catch (error) {
        return Err(
          ServerResponseInvalid(
            statusCode: reply.statusCode,
            description: error.message,
          ),
        );
      }
    });
  }
}
