# Changelog

## 0.7.0

The same native sign-in on Android, iOS, macOS, Linux and the web.

- Web: the challenge-based sign-in (every method, passkeys included) runs
  from the origins a first-party client registered (`allowed_web_origins`);
  `signInWithBrowser` stays available. Requires `enableDpop: true` and the
  app origin in the server's `CORS_ALLOWED_ORIGINS`; passkeys need
  Corbado's `bundle.js` in `web/index.html`.
- Web: a DPoP-bound session persists in `localStorage` (refresh token, ID
  token, metadata — never key material; the key stays a non-extractable
  WebCrypto key in IndexedDB). `initialize()` checks the stored key
  thumbprint and refreshes with the same key; a missing key or a refused
  refresh ends the session locally (`SignedOut(reason: sessionRevoked)`).
  Without DPoP the session stays in memory, as before.
- Sessions record the thumbprint of the DPoP key their tokens are bound to
  (`StoredSession.dpopJkt`); a restored DPoP-bound session is verified and
  refreshed at start-up on every platform.
- A refresh adopts a refresh token another instance over the same store
  already rotated (a second browser tab), instead of presenting the used
  one and revoking the family.
- New `LoginFlowAuth.authorizeResourceRequest` / `shouldRetryResourceRequest`
  and `ResourceAuthorization`: the `Authorization` and `DPoP` headers for
  the app's own API, with the per-server nonce cache and the single
  `use_dpop_nonce` retry. The library's own resource requests use the same
  code; DPoP nonces are now cached per origin.
- Linux: session and DPoP key in the Secret Service keyring through
  libsecret, via `flutter_secure_storage_linux` (plus its platform
  interface). Chosen over a hand-written libsecret channel: a maintained,
  widely used plugin (GNOME Keyring and KWallet), no C++ of ours to build
  and audit on a platform this library cannot test in CI, and it registers
  only on Linux, so Android/iOS/macOS/web apps carry no extra native code.
- Linux: browser steps open the default browser and wait on an RFC 8252
  §7.3 loopback redirect (`http://127.0.0.1:<fixed port>/<path>`, which the
  server accepts for native clients; ports are compared exactly, so the
  port is fixed and registered, not ephemeral).
- Linux: the DPoP key is a software ES256 key in the keyring (no OS API for
  a non-exportable key).
- Linux: passkeys fail as `PasskeyFailed(reason: notSupported)` instead of
  reaching a plugin that does not exist there.

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
