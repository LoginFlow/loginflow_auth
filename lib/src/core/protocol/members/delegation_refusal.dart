import 'package:loginflow_auth/src/core/error/delegation_denial_code.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/login_flow_envelope.dart';
import 'package:loginflow_auth/src/core/http/transport_reply.dart';

/// The error of a failed call to a door the delegation rules decide: the
/// members API (`doc/server-contract.md` §18) and the self-selectable roles
/// (§22).
extension DelegationRefusal on TransportReply {
  /// A refusal of the delegation rules is [DelegationDenied] with its code;
  /// anything else (step-up, rate limit, a malformed request) is the account
  /// API's usual error.
  LoginFlowError toDelegationError() => toAccountApiErrorOr((wireCode) {
    final code = DelegationDenialCode.fromWireName(wireCode);
    return code == null
        ? null
        : DelegationDenied(code: code, statusCode: statusCode);
  });
}
