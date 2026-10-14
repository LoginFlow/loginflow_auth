import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/core/config/login_flow_clock.dart';
import 'package:loginflow_auth/src/core/discovery/discovery_document.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:loginflow_auth/src/core/http/endpoint_security.dart';
import 'package:loginflow_auth/src/core/http/login_flow_transport.dart';
import 'package:result_controller/result_controller.dart';

/// Fetches and caches the issuer's discovery document.
class DiscoveryClient {
  DiscoveryClient({
    required this.issuer,
    required this.transport,
    required this.clock,
  });

  /// Cache lifetime when the response carries no `Cache-Control: max-age`.
  static const Duration defaultLifetime = Duration(hours: 1);

  final Uri issuer;
  final LoginFlowTransport transport;
  final LoginFlowClock clock;

  DiscoveryDocument? _cached;
  DateTime? _expiresAt;

  /// `{issuer}/.well-known/openid-configuration`: any trailing `/` of the
  /// issuer is removed before appending (OpenID Connect Discovery §4).
  Uri get configurationUri {
    final base = issuer.toString();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.parse('$trimmed/.well-known/openid-configuration');
  }

  Future<Result<DiscoveryDocument, LoginFlowError>> load() async {
    final cached = _cached;
    final expiresAt = _expiresAt;
    if (cached != null &&
        expiresAt != null &&
        clock.now().isBefore(expiresAt)) {
      return Ok(cached);
    }
    if (!issuer.isValidIssuer || !configurationUri.isSecureOrLoopback) {
      return Err(
        const DiscoveryInvalid(
          description: 'the issuer must be https without query or fragment',
        ),
      );
    }
    final reply = await transport.getJson(configurationUri);
    return reply.flatMap((reply) {
      if (!reply.isSuccess) {
        return Err(DiscoveryInvalid(description: 'HTTP ${reply.statusCode}'));
      }
      return reply.jsonObject().flatMap((json) {
        try {
          final document = DiscoveryDocument.fromJson(json);
          return _verified(document).map((document) {
            _cached = document;
            _expiresAt = clock.now().add(reply.maxAge ?? defaultLifetime);
            return document;
          });
        } on FormatException catch (error) {
          return Err(DiscoveryInvalid(description: error.message));
        }
      });
    });
  }

  Result<DiscoveryDocument, LoginFlowError> _verified(
    DiscoveryDocument document,
  ) {
    if (document.issuer != issuer.toString()) {
      Log.w('Discovery issuer ${document.issuer} differs from $issuer.');
      return Err(
        const DiscoveryInvalid(
          description: 'issuer does not match the configured issuer',
        ),
      );
    }
    if (!document.supportsS256) {
      return Err(
        const DiscoveryInvalid(
          description: 'code_challenge_methods_supported lacks S256',
        ),
      );
    }
    if (!document.isIssuerParameterSupported) {
      return Err(
        const DiscoveryInvalid(
          description:
              'authorization_response_iss_parameter_supported is not true',
        ),
      );
    }
    final endpoints = <Uri?>[
      document.authorizationEndpoint,
      document.tokenEndpoint,
      document.jwksUri,
      document.authorizationChallengeEndpoint,
      document.revocationEndpoint,
      document.endSessionEndpoint,
      document.loginOptionsEndpoint,
      document.deviceLogoutEndpoint,
      document.globalLogoutEndpoint,
    ].nonNulls;
    if (!endpoints.every((endpoint) => endpoint.isSecureOrLoopback)) {
      return Err(
        const DiscoveryInvalid(description: 'an endpoint is not https'),
      );
    }
    return Ok(document);
  }
}
