import 'package:loginflow_auth/src/core/browser/pending_purpose.dart';
import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// The secrets of a browser round-trip in flight. On the web it must survive
/// the full-page redirect, so it is serialized to `sessionStorage`, which is
/// scoped to the tab and cleared when the tab closes.
class PendingAuthorization {
  const PendingAuthorization({
    required this.purpose,
    required this.state,
    required this.redirectUri,
    required this.createdAt,
    this.codeVerifier,
    this.nonce,
  });

  factory PendingAuthorization.fromJson(Map<String, Object?> json) {
    final purposeName = json.requireString('purpose');
    final purpose = PendingPurpose.fromWireName(purposeName);
    if (purpose == null) {
      throw FormatException('Unknown pending purpose "$purposeName".');
    }
    return PendingAuthorization(
      purpose: purpose,
      state: json.requireString('state'),
      redirectUri: Uri.parse(json.requireString('redirect_uri')),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json.requireInt('created_at'),
        isUtc: true,
      ),
      codeVerifier: json.optionalString('code_verifier'),
      nonce: json.optionalString('nonce'),
    );
  }

  final PendingPurpose purpose;
  final String state;
  final Uri redirectUri;
  final DateTime createdAt;

  /// Absent for logout round-trips.
  final String? codeVerifier;
  final String? nonce;

  PendingAuthorization copyWith({
    PendingPurpose? purpose,
    String? state,
    Uri? redirectUri,
    DateTime? createdAt,
    String? codeVerifier,
    String? nonce,
  }) => PendingAuthorization(
    purpose: purpose ?? this.purpose,
    state: state ?? this.state,
    redirectUri: redirectUri ?? this.redirectUri,
    createdAt: createdAt ?? this.createdAt,
    codeVerifier: codeVerifier ?? this.codeVerifier,
    nonce: nonce ?? this.nonce,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'purpose': purpose.wireName,
    'state': state,
    'redirect_uri': redirectUri.toString(),
    'created_at': createdAt.millisecondsSinceEpoch,
    'code_verifier': ?codeVerifier,
    'nonce': ?nonce,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingAuthorization &&
          purpose == other.purpose &&
          state == other.state &&
          redirectUri == other.redirectUri &&
          createdAt == other.createdAt &&
          codeVerifier == other.codeVerifier &&
          nonce == other.nonce;

  @override
  int get hashCode =>
      Object.hash(purpose, state, redirectUri, createdAt, codeVerifier, nonce);

  @override
  String toString() => 'PendingAuthorization(purpose: ${purpose.name})';
}
