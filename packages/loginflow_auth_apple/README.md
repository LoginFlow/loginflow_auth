# loginflow_auth_apple

Optional native Sign in with Apple for `loginflow_auth`. It implements
`UpstreamTokenSource` with `AuthenticationServices` (via the
[`sign_in_with_apple`](https://pub.dev/packages/sign_in_with_apple) package)
on iOS and macOS, requesting the ID token with the nonce the server bound to
the sign-in attempt. Apps that do not offer Apple do not add this package
and carry no Apple SDK dependency.

```dart
final auth = LoginFlowPlatform.createAuth(
  config: config,
  appleTokenSource: NativeAppleTokenSource(),
);
```

`isAvailable` is `false` on every platform other than iOS/macOS — in
particular Android, where the library deliberately does **not** fall back to
Apple's own web authentication flow. With no source registered, or on a
platform where it reports itself unavailable, `signInWithApple()` falls back
to the hosted page in the system browser (never a `WebView`), the same way
Google does today without `loginflow_auth_google`.

## Setup

1. In Xcode, add the **Sign in with Apple** capability to the app target
   (Signing & Capabilities). This is required even though the app never
   talks to Apple's REST API directly — `AuthenticationServices` checks for
   it at runtime.
2. The company's **Services ID** (or the app's bundle ID, for the native
   ceremony) must match what is configured for this client on LoginFlow's
   side — ask the team managing the server's `oauth_provider_configs` for
   Apple before enabling the button in `SignInConfiguration`.
3. No extra Dart configuration: the server does not publish an
   Apple-specific client ID through `GET /oauth2/login-options` (unlike
   Google) — the native ceremony resolves entirely from the app's own Xcode
   capability and bundle/Services ID.

## First authorization only

Apple returns the user's given/family name **once**, on the very first
authorization for that Apple ID + app pair; every later sign-in omits it.
`NativeAppleTokenSource` forwards whatever it received on that attempt as
`upstream_user_name` — the app does not need to cache it itself.

Setup is described in the main README, section "Apple (optional package)".
