import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/device_push/phone_approval_requester.dart';

/// Who asks to sign in with a scanned QR
/// (`POST /v1/user/device-qr/{request_id}/details`,
/// `doc/server-contract.md` §21): show [clientName] and [requester] before
/// the person approves (`LoginFlowAuth.approveQrSignIn`) or refuses
/// (`LoginFlowAuth.denyQrSignIn`). Reading never changes the QR.
class SignInQrDetails {
  /// Creates a [SignInQrDetails].
  const SignInQrDetails({
    required this.requestId,
    required this.clientId,
    required this.clientName,
    required this.applicationId,
    required this.requester,
    required this.createdAt,
    required this.expiresAt,
  });

  /// Reads a [SignInQrDetails] from its JSON form ([toJson]).
  factory SignInQrDetails.fromJson(Map<String, Object?> json) =>
      SignInQrDetails(
        requestId: json.requireString('request_id'),
        clientId: json.requireString('client_id'),
        clientName: json.requireString('client_name'),
        applicationId: json.requireString('application_id'),
        requester: PhoneApprovalRequester.fromJson(
          json.requireObject('requester'),
        ),
        createdAt: json.requireUtcDateTime('created_at'),
        expiresAt: json.requireUtcDateTime('expires_at'),
      );

  /// The QR's request id.
  final String requestId;

  /// The OAuth client the page signs in to.
  final String clientId;

  /// Its display name, e.g. `Payments panel`.
  final String clientName;

  /// The application of that client.
  final String applicationId;

  /// The page that shows the QR: its device and address.
  final PhoneApprovalRequester requester;

  /// When the page showed the QR (UTC).
  final DateTime createdAt;

  /// When the QR stops being answerable (UTC), 120 s after [createdAt].
  final DateTime expiresAt;

  /// A copy of this [SignInQrDetails] with the given fields replaced.
  SignInQrDetails copyWith({
    String? requestId,
    String? clientId,
    String? clientName,
    String? applicationId,
    PhoneApprovalRequester? requester,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) => SignInQrDetails(
    requestId: requestId ?? this.requestId,
    clientId: clientId ?? this.clientId,
    clientName: clientName ?? this.clientName,
    applicationId: applicationId ?? this.applicationId,
    requester: requester ?? this.requester,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  /// The JSON form of this [SignInQrDetails], read back by
  /// [SignInQrDetails.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'request_id': requestId,
    'client_id': clientId,
    'client_name': clientName,
    'application_id': applicationId,
    'requester': requester.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInQrDetails &&
          requestId == other.requestId &&
          clientId == other.clientId &&
          clientName == other.clientName &&
          applicationId == other.applicationId &&
          requester == other.requester &&
          createdAt == other.createdAt &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(
    requestId,
    clientId,
    clientName,
    applicationId,
    requester,
    createdAt,
    expiresAt,
  );
}
