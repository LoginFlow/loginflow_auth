import 'package:loginflow_auth/src/core/error/delegation_denial_code.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/members/grantable_roles.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_assignment.dart';
import 'package:loginflow_auth/src/core/protocol/members/member_invitation.dart';
import 'package:loginflow_auth/src/core/protocol/members/members_page.dart';
import 'package:result_controller/result_controller.dart';

/// LoginFlow's members API (`/v1/app/members/*`, `doc/server-contract.md`
/// §18): the signed-in person manages who holds which role in the
/// organizations their own roles reach. Every call carries the person's own
/// LoginFlow token (`aud` = the issuer), DPoP-bound; the server decides every
/// grant and revocation with its delegation rules.
///
/// Fixed account-API paths resolved from [issuer], like the passkey API,
/// not from discovery.
class AppMembersClient {
  const AppMembersClient({required this.transport, required this.issuer});

  final LoginFlowTransport transport;
  final Uri issuer;

  Uri get _collection => issuer.replace(path: '${issuer.path}/v1/app/members');

  Uri _path(String suffix, [Map<String, String>? query]) => _collection.replace(
    path: '${_collection.path}$suffix',
    queryParameters: query,
  );

  /// `GET /v1/app/members/grantable-roles?organization_id=`.
  Future<Result<GrantableRoles, LoginFlowError>> grantableRoles({
    required String bearerToken,
    required String organizationId,
  }) async {
    final reply = await transport.getJson(
      _path('/grantable-roles', <String, String>{
        'organization_id': organizationId,
      }),
      bearerToken: bearerToken,
    );
    return reply.flatMap((reply) => _model(reply, GrantableRoles.fromJson));
  }

  /// `GET /v1/app/members?organization_id=&q=&limit=&offset=`.
  Future<Result<MembersPage, LoginFlowError>> list({
    required String bearerToken,
    required String organizationId,
    required int limit,
    required int offset,
    String? query,
  }) async {
    final reply = await transport.getJson(
      _path('', <String, String>{
        'organization_id': organizationId,
        'q': ?query,
        'limit': '$limit',
        'offset': '$offset',
      }),
      bearerToken: bearerToken,
    );
    return reply.flatMap((reply) => _model(reply, MembersPage.fromJson));
  }

  /// `POST /v1/app/members/invitations`.
  Future<Result<MemberInvitation, LoginFlowError>> invite({
    required String bearerToken,
    required String organizationId,
    required String email,
    required String roleId,
    String? firstName,
    String? lastName,
    DateTime? expiresAt,
  }) async {
    final reply = await transport.postJson(
      _path('/invitations'),
      <String, Object?>{
        'organization_id': organizationId,
        'email': email,
        'first_name': ?firstName,
        'last_name': ?lastName,
        'role_id': roleId,
        'expires_at': ?expiresAt?.toUtc().toIso8601String(),
      },
      bearerToken: bearerToken,
    );
    return reply.flatMap((reply) => _model(reply, MemberInvitation.fromJson));
  }

  /// `POST /v1/app/members/{principal_id}/assignments`.
  Future<Result<MemberAssignment, LoginFlowError>> grant({
    required String bearerToken,
    required String organizationId,
    required String principalId,
    required String roleId,
    DateTime? expiresAt,
  }) async {
    final reply = await transport.postJson(
      _path('/${Uri.encodeComponent(principalId)}/assignments'),
      <String, Object?>{
        'organization_id': organizationId,
        'role_id': roleId,
        'expires_at': ?expiresAt?.toUtc().toIso8601String(),
      },
      bearerToken: bearerToken,
    );
    return reply.flatMap((reply) => _model(reply, MemberAssignment.fromJson));
  }

  /// `DELETE /v1/app/members/assignments/{assignment_id}` (`204`).
  Future<Result<void, LoginFlowError>> revoke({
    required String bearerToken,
    required String assignmentId,
  }) async {
    final reply = await transport.deleteJson(
      _path('/assignments/${Uri.encodeComponent(assignmentId)}'),
      bearerToken: bearerToken,
    );
    return reply.flatMap(
      (reply) => reply.isSuccess ? Ok(null) : Err(_error(reply)),
    );
  }

  Result<T, LoginFlowError> _model<T>(
    TransportReply reply,
    T Function(Map<String, Object?> json) fromJson,
  ) => reply.isSuccess ? reply.envelopeModel(fromJson) : Err(_error(reply));

  /// A refusal of the delegation rules is [DelegationDenied] with its code;
  /// anything else (step-up, rate limit, a malformed request) is the account
  /// API's usual error.
  LoginFlowError _error(TransportReply reply) {
    final code = reply.jsonObject().when(
      ok: (json) {
        final wireCode = json.optionalObject('error')?.optionalString('code');
        return wireCode == null
            ? null
            : DelegationDenialCode.fromWireName(wireCode);
      },
      err: (_) => null,
    );
    if (code == null) {
      return reply.toAccountApiError();
    }
    return DelegationDenied(code: code, statusCode: reply.statusCode);
  }
}
