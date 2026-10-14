import 'package:loginflow_auth/src/core/json/json_field_reader.dart';

/// What a particular ID token must satisfy beyond signature and issuer.
class IdTokenExpectations {
  const IdTokenExpectations({
    required this.audience,
    this.nonce,
    this.subject,
    this.allowExpired = false,
  });

  factory IdTokenExpectations.fromJson(Map<String, Object?> json) =>
      IdTokenExpectations(
        audience: json.optionalString('audience'),
        nonce: json.optionalString('nonce'),
        subject: json.optionalString('subject'),
        allowExpired: json.optionalBool('allow_expired', absent: false),
      );

  /// Tokens issued to this app: `aud` must contain [clientId]
  /// (OpenID Connect Core §3.1.3.7 steps 3–5).
  const IdTokenExpectations.forClient({
    required String clientId,
    String? nonce,
    String? subject,
  }) : this(audience: clientId, nonce: nonce, subject: subject);

  /// A sibling app's ID token read from the shared Native SSO store: the
  /// audience is another client and it may be expired (OpenID Connect Native
  /// SSO §6.3). Only signature and issuer are checked before the claims are
  /// shown in a "Continue as" prompt.
  const IdTokenExpectations.sharedSsoToken()
    : this(audience: null, allowExpired: true);

  /// Expected `aud` member; `null` skips the audience and `azp` checks.
  final String? audience;

  /// Expected `nonce`; `null` skips the nonce check.
  final String? nonce;

  /// Expected `sub` (refresh and step-up must stay on the same user).
  final String? subject;

  final bool allowExpired;

  IdTokenExpectations copyWith({
    String? audience,
    String? nonce,
    String? subject,
    bool? allowExpired,
  }) => IdTokenExpectations(
    audience: audience ?? this.audience,
    nonce: nonce ?? this.nonce,
    subject: subject ?? this.subject,
    allowExpired: allowExpired ?? this.allowExpired,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'audience': ?audience,
    'nonce': ?nonce,
    'subject': ?subject,
    'allow_expired': allowExpired,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdTokenExpectations &&
          audience == other.audience &&
          nonce == other.nonce &&
          subject == other.subject &&
          allowExpired == other.allowExpired;

  @override
  int get hashCode => Object.hash(audience, nonce, subject, allowExpired);
}
