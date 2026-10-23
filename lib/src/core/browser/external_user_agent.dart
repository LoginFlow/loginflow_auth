import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// The system browser (RFC 8252 §6): ASWebAuthenticationSession on Apple
/// platforms, Custom Tabs on Android, a top-level navigation on the web.
/// Embedded web views are never used (RFC 8252 §8.12).
abstract interface class ExternalUserAgent {
  /// Opens [url] and waits for a navigation to [callbackUri] carrying
  /// [expectedState]. Implementations that can see several navigations
  /// (Android Custom Tabs) ignore any other callback and keep waiting
  /// (`doc/decisions.md` D17).
  Future<Result<UserAgentOutcome, LoginFlowError>> open(
    Uri url, {
    required Uri callbackUri,
    required String expectedState,
  });

  /// Removes the callback parameters (`code`, `state`) from the visible
  /// location once they were consumed. Only meaningful on the web.
  Future<void> discardCallback(Uri cleanUri);
}

/// How [ExternalUserAgent.open] ended.
///
/// Outcomes are transient values that are never stored, so they have no
/// `toJson`/`fromJson`.
sealed class UserAgentOutcome {
  const UserAgentOutcome();
}

/// The browser came back to the callback URI with [uri].
final class UserAgentCallback extends UserAgentOutcome {
  /// Creates an [UserAgentCallback].
  const UserAgentCallback({required this.uri});

  /// The callback URI, with its response parameters (`code`, `state`, `iss`, or `error`).
  final Uri uri;

  /// A copy of this [UserAgentCallback] with the given fields replaced.
  UserAgentCallback copyWith({Uri? uri}) =>
      UserAgentCallback(uri: uri ?? this.uri);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserAgentCallback && uri == other.uri;

  @override
  int get hashCode => uri.hashCode;
}

/// The page navigated away (web full-page redirect); the app completes the
/// flow with `completeBrowserRedirect` after it reloads.
final class UserAgentNavigatedAway extends UserAgentOutcome {
  /// Creates an [UserAgentNavigatedAway].
  const UserAgentNavigatedAway();

  @override
  bool operator ==(Object other) => other is UserAgentNavigatedAway;

  @override
  int get hashCode => (UserAgentNavigatedAway).hashCode;
}
