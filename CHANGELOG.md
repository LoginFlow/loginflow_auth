# Changelog

## 0.1.0

First version.

- Native first-party sign-in through the Authorization Challenge Endpoint
  (draft-ietf-oauth-first-party-apps-04): password, email OTP with resend,
  TOTP and recovery codes, method selection, step-up (RFC 9470) and
  re-authentication requested by the token endpoint.
- System-browser fallback for `redirect_to_web` (PAR `request_uri`),
  Microsoft, sign-up (`prompt=create`) and password reset; `state` and `iss`
  (RFC 9207) validation; web top-level redirect with `prompt=none`.
- Google sign-in with a server-issued nonce, natively through the optional
  `loginflow_auth_google` package or in the browser.
- ID token validation: RS256/ES256 through a `kid`-cached JWKS, `iss`, `aud`,
  `azp`, `exp`, `iat`, `nonce`, `typ`, `crit`, subject continuity.
- Token lifecycle: in-memory access tokens, single-flight refresh with
  rotation, logout on a rejected refresh token.
- OpenID Connect Native SSO: `device_sso`, shared `device_secret` + ID token
  (iOS/macOS Keychain access group, Android signature-protected
  ContentProvider), RFC 8693 token exchange.
- Logout levels: app (RFC 7009 revocation), device session, browser
  (RP-initiated logout), everywhere.
- Secure storage: Keychain (`AfterFirstUnlockThisDeviceOnly`, never synced),
  Android Keystore AES-GCM; memory only on the web.
- Ready-to-use sign-in UI configured by `SignInConfiguration` (sealed
  `AuthMethod`s, per-method options, self sign-up, branding copy), English
  and Spanish, adaptive mobile/tablet/desktop layout, themable through
  `LoginFlowSignInTheme`.
- `doc/server-contract.md`: the HTTP contract the server implements;
  `doc/decisions.md`: the design decisions with their normative sources.
- `beginSignIn` opens a sign-in without a method (`next: select_method`).
- A refresh that finishes after its session ended is discarded and its
  token revoked; rotated refresh tokens are persisted before use.
- Browser callbacks must target the pending redirect URI with the pending
  `state`; others are ignored; pending requests expire after 10 minutes.
- The configuration and the discovery issuer must be `https`; the server
  must support the `iss` authorization response parameter (RFC 9207).
