import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// What `LoginFlowAuth.approvePhoneSignIn` decided
/// (`POST /v1/user/device-push/{request_id}/approve`,
/// `doc/server-contract.md` §21). Both are final: the request is over
/// either way.
enum PhoneApprovalOutcome {
  /// The number was the page's: the page signs in as the signed-in person.
  approved,

  /// The number was not the page's: the request is denied for good (one
  /// try). The person asks again from the page if it was a slip.
  wrongNumber;

  /// Reads the decision (`{"request_id", "status", "reason"?}`): `approved`,
  /// or `denied` with `reason: wrong_number`. Throws a [FormatException]
  /// for anything else — an approval never answers a plain `denied`.
  static PhoneApprovalOutcome fromDecision(Map<String, Object?> json) =>
      switch ((json.requireString('status'), json.optionalString('reason'))) {
        ('approved', _) => PhoneApprovalOutcome.approved,
        ('denied', 'wrong_number') => PhoneApprovalOutcome.wrongNumber,
        (final status, final reason) => throw FormatException(
          'Unknown approval decision "$status" (reason: $reason).',
        ),
      };
}
