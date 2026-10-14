# loginflow_auth_google

Optional native Google sign-in for `loginflow_auth`. It implements
`GoogleIdTokenSource` with Credential Manager (Android) and GIDSignIn (iOS),
requesting the ID token for LoginFlow's Google web client with the nonce the
server bound to the sign-in attempt. Apps that do not offer Google do not add
this package and carry no Google SDK.

```dart
final auth = LoginFlowPlatform.createAuth(
  config: config,
  googleIdTokenSource: const NativeGoogleIdTokenSource(),
);
```

Setup is described in the main README, section "Google (optional package)".
