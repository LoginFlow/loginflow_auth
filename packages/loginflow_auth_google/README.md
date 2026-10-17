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

No Google client ID to configure here: the server supplies it per attempt
(`UpstreamPrompt.clientId`), the same value it publishes ahead of time as
`ClientLoginOptions.googleServerClientId` from `GET /oauth2/login-options`
(`doc/server-contract.md` §4 in the main package). Pass
`NativeGoogleIdTokenSource(serverClientId: ...)` only to force a different
one — local testing against a server that has not configured Google yet,
for example; never for a real deployment.

Setup is described in the main README, section "Google (optional package)".
