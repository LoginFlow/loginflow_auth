# Changelog

## 0.6.0

Aligned with LoginFlow API and `loginflow_sdk` 0.6.0 (LTS line).

- DPoP (RFC 9449): non-exportable ES256 key per platform (Secure Enclave,
  Android Keystore/StrongBox, non-extractable WebCrypto key), proof on every
  request, `DPoP-Nonce` handshake; retries only on `use_dpop_nonce`.
- Passkeys: sign-in (targeted and discoverable), account management
  (enroll, list, rename, delete) and Temporary Access Pass, through the
  bundled Corbado `passkeys` adapter.
- Sign in with Apple and Continue with Facebook as optional packages
  (`loginflow_auth_apple`, `loginflow_auth_facebook`), sharing one generic
  upstream-token step with Google; browser fallback when no native source.
- Magic link per app: `magicLinkTokenFromUri` accepts only
  `https://<host>/login/magic/<this app's client_id>`.
- Sign-in UI driven by `GET /oauth2/login-options`: methods, passkey policy,
  provider buttons, sign-up and reset are shown only when the server allows
  them; legal links footer (`policy_uri`, `tos_uri`).
- Spanish and English (ARB), per-app branding (colors, logo, typography).
- Goldens for every sign-in screen (light/dark, phone/tablet).

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
