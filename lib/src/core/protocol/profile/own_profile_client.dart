import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/protocol/profile/own_profile.dart';
import 'package:result_controller/result_controller.dart';

/// LoginFlow's own profile (`/v1/app/profile`, `doc/server-contract.md`
/// §24): the signed-in person reads and completes their OWN names. Same door
/// as the email change: the person's own LoginFlow token (`aud` = the
/// issuer), DPoP-bound, no step-up.
///
/// A fixed account-API path resolved from [issuer], not from discovery.
class OwnProfileClient {
  const OwnProfileClient({required this.transport, required this.issuer});

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri get _profileUri => issuer.replace(path: '${issuer.path}/v1/app/profile');

  /// `GET /v1/app/profile` (`200`).
  Future<Result<OwnProfile, LoginFlowError>> read({
    required String bearerToken,
  }) async {
    final reply = await transport.getJson(
      _profileUri,
      bearerToken: bearerToken,
    );
    return reply.flatMap(_toProfile);
  }

  /// `PATCH /v1/app/profile` (`200`, the profile after the change). Only the
  /// names given are sent; a name left out keeps its value.
  Future<Result<OwnProfile, LoginFlowError>> update({
    required String bearerToken,
    String? firstName,
    String? lastName,
  }) async {
    final reply = await transport.patchJson(_profileUri, <String, Object?>{
      'first_name': ?firstName,
      'last_name': ?lastName,
    }, bearerToken: bearerToken);
    return reply.flatMap(_toProfile);
  }

  /// A `422` is a refused name (or an update that sets none); anything else
  /// is the account API's usual error.
  Result<OwnProfile, LoginFlowError> _toProfile(TransportReply reply) {
    if (reply.isSuccess) {
      return reply.envelopeModel(OwnProfile.fromJson);
    }
    return Err(
      reply.statusCode == 422
          ? const InvalidProfileName()
          : reply.toAccountApiError(),
    );
  }
}
