import 'package:loginflow_auth/src/core/json/json_field_reader.dart';
import 'package:loginflow_auth/src/core/protocol/challenge/upstream_provider.dart';

/// What the server gives the app to request an upstream ID token natively:
/// the provider, the server-generated `nonce` bound to the `auth_session`, and
/// the provider client ID the token must be issued to (the `upstream` member).
class UpstreamPrompt {
  const UpstreamPrompt({
    required this.provider,
    required this.nonce,
    required this.clientId,
  });

  factory UpstreamPrompt.fromJson(Map<String, Object?> json) {
    final providerName = json.requireString('provider');
    final provider = UpstreamProvider.fromWireName(providerName);
    if (provider == null) {
      throw FormatException('Unknown upstream provider "$providerName".');
    }
    return UpstreamPrompt(
      provider: provider,
      nonce: json.requireString('nonce'),
      clientId: json.requireString('client_id'),
    );
  }

  final UpstreamProvider provider;
  final String nonce;

  /// For Google: the company's Google *web* client ID, passed to the SDK as
  /// `serverClientId` so the ID token audience is the one LoginFlow verifies.
  final String clientId;

  UpstreamPrompt copyWith({
    UpstreamProvider? provider,
    String? nonce,
    String? clientId,
  }) => UpstreamPrompt(
    provider: provider ?? this.provider,
    nonce: nonce ?? this.nonce,
    clientId: clientId ?? this.clientId,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'provider': provider.wireName,
    'nonce': nonce,
    'client_id': clientId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpstreamPrompt &&
          provider == other.provider &&
          nonce == other.nonce &&
          clientId == other.clientId;

  @override
  int get hashCode => Object.hash(provider, nonce, clientId);
}
