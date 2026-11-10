import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/json/list_equality.dart';
import 'package:loginflow_auth/src/core/protocol/device_push/phone_approval_requester.dart';

/// A sign-in by phone approval waiting for the signed-in person
/// (`GET /v1/user/device-push/pending`, `doc/server-contract.md` §21): a web
/// page of the same company asked to sign in as them and shows a two-digit
/// number. Show [clientName], [requester] and the three [choices] as
/// buttons; the person picks the number the page shows
/// (`LoginFlowAuth.approvePhoneSignIn`) or refuses
/// (`LoginFlowAuth.denyPhoneSignIn`).
class PhoneApprovalRequest {
  /// Creates a [PhoneApprovalRequest].
  const PhoneApprovalRequest({
    required this.requestId,
    required this.clientId,
    required this.clientName,
    required this.applicationId,
    required this.requester,
    required this.choices,
    required this.createdAt,
    required this.expiresAt,
  });

  /// Reads a [PhoneApprovalRequest] from its JSON form ([toJson]).
  factory PhoneApprovalRequest.fromJson(Map<String, Object?> json) =>
      PhoneApprovalRequest(
        requestId: json.requireString('request_id'),
        clientId: json.requireString('client_id'),
        clientName: json.requireString('client_name'),
        applicationId: json.requireString('application_id'),
        requester: PhoneApprovalRequester.fromJson(
          json.requireObject('requester'),
        ),
        choices: List<int>.unmodifiable(json.intList('choices')),
        createdAt: json.requireUtcDateTime('created_at'),
        expiresAt: json.requireUtcDateTime('expires_at'),
      );

  /// The request's identifier, for `LoginFlowAuth.approvePhoneSignIn` and
  /// `LoginFlowAuth.denyPhoneSignIn`.
  final String requestId;

  /// The OAuth client the page signs in to.
  final String clientId;

  /// Its display name, e.g. `Payments panel`.
  final String clientName;

  /// The application of that client.
  final String applicationId;

  /// The page that asked: its device and address.
  final PhoneApprovalRequester requester;

  /// Three distinct two-digit numbers, the page's among them, always in
  /// this order for this request. The page's number is never sent alone.
  final List<int> choices;

  /// When the page asked (UTC).
  final DateTime createdAt;

  /// When the request stops being answerable (UTC), 120 s after
  /// [createdAt].
  final DateTime expiresAt;

  /// A copy of this [PhoneApprovalRequest] with the given fields replaced.
  PhoneApprovalRequest copyWith({
    String? requestId,
    String? clientId,
    String? clientName,
    String? applicationId,
    PhoneApprovalRequester? requester,
    List<int>? choices,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) => PhoneApprovalRequest(
    requestId: requestId ?? this.requestId,
    clientId: clientId ?? this.clientId,
    clientName: clientName ?? this.clientName,
    applicationId: applicationId ?? this.applicationId,
    requester: requester ?? this.requester,
    choices: choices ?? this.choices,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  /// The JSON form of this [PhoneApprovalRequest], read back by [PhoneApprovalRequest.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'request_id': requestId,
    'client_id': clientId,
    'client_name': clientName,
    'application_id': applicationId,
    'requester': requester.toJson(),
    'choices': choices,
    'created_at': createdAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneApprovalRequest &&
          requestId == other.requestId &&
          clientId == other.clientId &&
          clientName == other.clientName &&
          applicationId == other.applicationId &&
          requester == other.requester &&
          choices.hasSameValues(other.choices) &&
          createdAt == other.createdAt &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(
    requestId,
    clientId,
    clientName,
    applicationId,
    requester,
    choices.valuesHash,
    createdAt,
    expiresAt,
  );
}
