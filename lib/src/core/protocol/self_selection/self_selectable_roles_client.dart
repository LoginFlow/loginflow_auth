import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/protocol/members/delegation_refusal.dart';
import 'package:loginflow_auth/src/core/protocol/self_selection/self_selectable_roles.dart';
import 'package:loginflow_auth/src/core/protocol/self_selection/self_selected_role.dart';
import 'package:result_controller/result_controller.dart';

/// LoginFlow's self-selectable roles (`/v1/app/self-selectable-roles`,
/// `doc/server-contract.md` §22): the signed-in person takes or leaves, for
/// themself, the roles the application's owner marked self-selectable, in
/// the root organization of their company and application. Same door as
/// the members API: the person's own LoginFlow token (`aud` = the issuer),
/// DPoP-bound, no step-up.
///
/// Fixed account-API paths resolved from [issuer], not from discovery.
class SelfSelectableRolesClient {
  const SelfSelectableRolesClient({
    required this.transport,
    required this.issuer,
  });

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri get _collection =>
      issuer.replace(path: '${issuer.path}/v1/app/self-selectable-roles');

  Uri _role(String roleId) => _collection.replace(
    path: '${_collection.path}/${Uri.encodeComponent(roleId)}',
  );

  /// `GET /v1/app/self-selectable-roles`.
  Future<Result<SelfSelectableRoles, LoginFlowError>> list({
    required String bearerToken,
  }) async {
    final reply = await transport.getJson(
      _collection,
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(SelfSelectableRoles.fromJson)
          : Err(reply.toDelegationError()),
    );
  }

  /// `PUT /v1/app/self-selectable-roles/{role_id}`: `201` new, `200`
  /// already held, the same body.
  Future<Result<SelfSelectedRole, LoginFlowError>> take({
    required String bearerToken,
    required String roleId,
  }) async {
    final reply = await transport.putJson(
      _role(roleId),
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess
          ? reply.envelopeModel(
              (json) => SelfSelectedRole.fromJson(<String, Object?>{
                ...json,
                'created': reply.statusCode == 201,
              }),
            )
          : Err(reply.toDelegationError()),
    );
  }

  /// `DELETE /v1/app/self-selectable-roles/{role_id}` (`204`).
  Future<Result<void, LoginFlowError>> leave({
    required String bearerToken,
    required String roleId,
  }) async {
    final reply = await transport.deleteJson(
      _role(roleId),
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess ? Ok(null) : Err(reply.toDelegationError()),
    );
  }
}
