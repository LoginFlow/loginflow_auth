# Changelog

## 0.9.2

- Fix: on the web (and every platform using the `passkeys` plugin), a
  passkey sign-in failed with `invalidResponse` before the browser was
  asked, and so did enrolling a second passkey. LoginFlow's webauthn-rs
  sends `allowCredentials` / `excludeCredentials` descriptors without
  `transports` (it asks for no attestation), and the plugin's parser
  requires them. The adapter now fills a missing `transports` with `[]`,
  maps `ble` to `bluetooth` and drops names the plugin does not support.

## 0.9.1

- Fix: `stepUp` no longer gives up when the server answers `invalid_session`
  for the stored `auth_session` (a session that came from a browser or
  hosted flow). It retries once with `id_token_hint`, as the server contract
  allows (§5.2), so re-authentication before enrolling a passkey works past
  the 5-minute window.
- Fix: the bundled UI's re-authentication (a step-up such as the one
  `LoginFlowPasskeys` runs before adding a passkey, or a re-authentication
  after a refresh) no longer dead-ends on the password step. The server
  opens it with `next: password` and no `methods`, but also takes an email
  code on that `auth_session`; so the step now offers "Email me a code"
  (`SignInPasswordEntry.isEmailCodeOffered`) whenever the client's login
  options list `email_otp` — or the prompt's `methods` do, if the server
  ever sends them. It calls `selectMethod(ChallengeStep.emailOtp)`
  (`SignInViewModel.useEmailCode`), then the usual code step with resend.
  Accounts with a password nobody knows (created through a tenant's
  backend) can step up with an email code.
- Fix: `stepUp` keeps the signed-in user's email as the prompt's
  `loginHint`, so the code step reads "code sent to <email>" instead of an
  empty address.

## 0.9.0

The prebuilt UI signs in with an access code and manages passkeys, so no
app has to build either screen.

- New: access-code sign-in in `LoginFlowSignIn`, opt-in through
  `SignInConfiguration.isAccessCodeOffered` (JSON `access_code`, default
  `false`) — the server's login options never advertise access codes, so
  the app opts in. "I have an access code" appears on the method picker,
  the password step and the email step; with no other method allowed the
  access-code step is the entry screen. The field uses
  `AccessCodeInputFormatter`; an incomplete code is refused locally (no
  request); the code is redeemed with `signInWithAccessCode`, and each
  failure has its own message: `InvalidAccessCode`,
  `AccessCodesUnavailable` and `UnsupportedByServer`,
  `ConfigurationInvalid` (no DPoP), network; `AccessCodeThrottled` is the
  lockout countdown from its `retryAfter`, like `RateLimited`. The busy
  state always ends.
- Changed: in the bundled UI, `InvalidAccessCode` and
  `AccessCodesUnavailable` now show access-code messages instead of the
  generic "wrong credentials" and "option not available".
- New: `LoginFlowPasskeys`, a prebuilt passkey manager for the signed-in
  user (mobile and tablet/desktop layouts, `LoginFlowSignInTheme`, `en` +
  `es`): lists passkeys (`listPasskeys`), adds (`enrollPasskey`, with
  `username`/`displayName` from its parameters or the session identity),
  renames (`renamePasskey`) and deletes (`deletePasskey`, behind a
  confirmation). On `StepUpRequired` it calls `stepUp` with the server's
  requirement, shows the requested step with the sign-in UI's own screens,
  and retries the enrollment once after the user signs in again (cancel
  goes back to the list). A failed ceremony shows its real
  `PasskeyFailed` reason. Needs `LoginFlowSignInSetup.install`. No "Add a
  passkey" for an access-code `device` subject.
- New strings in both `login_flow_en.arb` and `login_flow_es.arb`.

## 0.8.1

- Fix: a native challenge sign-in failed with `invalid_grant`
  (`redirect_uri mismatch`) whenever the client configured a `redirectUri`.
  The opening request sends it, the server binds the code to it, and the
  code redemption now presents that same `redirect_uri` instead of none.

## 0.8.0

Access codes: sign-in for people and devices that live in the tenant's own
backend (`doc/server-contract.md` §16).

- New: `LoginFlowAuth.signInWithAccessCode(code)` redeems a single-use code
  a tenant backend issued (`method=access_code` on the native challenge,
  one leg), returning the same `Result<AuthState, LoginFlowError>` as the
  other sign-in methods. DPoP is required — the session is bound to the
  device key —; a client without `enableDpop` and a DPoP key store fails
  with `ConfigurationInvalid` before any request. A malformed code fails
  locally, without a request.
- New errors (`LoginFlowError`): `InvalidAccessCode` (malformed, unknown,
  expired, used or revoked — never told apart), `AccessCodeThrottled`
  (`retryAfter`, from `429`/`slow_down`) and `AccessCodesUnavailable`
  (`access_codes_disabled`, or a server without the method). Exhaustive
  switches over `LoginFlowError` must handle the new subtypes. A server
  whose discovery has no `authorization_challenge_endpoint` fails with
  `UnsupportedByServer`; any other refusal comes back as
  `OAuthProtocolError`.
- New: `UserIdentity.externalSubject`, `subjectKind` (`AccessSubjectKind`:
  `person`/`device`) and `subjectProfile`, from the `ext_sub`/
  `subject_kind`/`ext_profile` claims; `null` for regular users (read only
  when `ext_sub` is present). The label is `ext_profile`, never the standard
  `profile` claim (a profile-page URL in OpenID Connect Core §5.1), which
  the library does not read. Same fields on `IdTokenClaims`.
- New: `AccessCodeFormat` (alphabet without `0 O 1 I L`, length 8,
  `normalize`, `filter`, `isComplete`, `display` as `XXXX-XXXX`) and
  `AccessCodeInputFormatter`, a `TextInputFormatter` that uppercases,
  filters to the alphabet and inserts the dash — one implementation for
  every app.
- New: `ChallengeStep.accessCode` (client-initiated only). Exhaustive
  switches over `ChallengeStep` must handle it.

## 0.7.2

- Fixed: a passkey ceremony could hang forever. The server sends
  `mediation: "conditional"` for a discoverable request (no `login_hint`),
  and `CorbadoPasskeyAuthenticator` forwarded it as
  `MediationType.Conditional` — an autofill-only request that, with no
  autofill field, never resolves on iOS and the web. Every ceremony is now
  modal, as documented, and bounded by the new
  `CorbadoPasskeyAuthenticator.ceremonyTimeout` (default
  `defaultCeremonyTimeout`, 120 s), after which the stuck sheet is
  cancelled and the ceremony fails as `PasskeyFailed(reason: timeout)`.
- Fixed: `CorbadoPasskeyAuthenticator` caught only Corbado's
  `AuthenticatorException`, so the errors the plugin rethrows as a raw
  `PlatformException` (WebAuthn `SecurityError`, `InvalidStateError`,
  `AbortError`, `NotSupportedError` on the web; Android Credential
  Manager DOM errors), `FormatException` and `TypeError` from malformed
  JSON, or anything else escaped to the caller as exceptions. Every failure
  is now a `PasskeyFailed`.
- New: `PasskeyFailureReason.securityError`, `domainNotAssociated`
  (previously folded into `notSupported`), `alreadyRegistered` (previously
  folded into `invalidResponse`), `timeout` and `unknown`; and
  `PasskeyFailed.code`/`description`, the platform's original error for
  logs. Exhaustive switches over `PasskeyFailureReason` must handle the
  new values.
- New: `StepUpRequired` (a `LoginFlowError`): `enrollPasskey` — and the
  other `/v1/user/passkeys*` calls — fail with it, carrying the server's
  `StepUpRequirement`, when the RFC 9470 recent-authentication gate
  answers `401` with `WWW-Authenticate: Bearer
  error="insufficient_user_authentication"`; previously an opaque
  `ServerResponseInvalid(statusCode: 401)`. Re-authenticate with
  `LoginFlowAuth.stepUp(requirement)` and retry. Exhaustive switches over
  `LoginFlowError` must handle the new subtype.
- Fixed: the bundled sign-in UI could stay busy for good: an action that
  threw (a misbehaving adapter) left the in-flight guard set, so every
  later tap was ignored, and the passkey auto-suggest had the same gap.
  Both now always release it, and a thrown action shows the generic error.

## 0.7.1

- Fixed: `PasskeyAccountClient` (`enrollPasskey`, `listPasskeys`,
  `renamePasskey`, `deletePasskey`) parsed the raw response body of every
  `/v1/user/passkeys*` call as the payload, instead of unwrapping LoginFlow's
  standard `{"data": <payload>, "meta": {...}}` envelope — `listPasskeys`
  always failed with `ServerResponseInvalid` ("not a JSON array"), and the
  other three failed as soon as `PasskeyCredential.fromJson` could not find
  `id`/`name`/`created_at` on the envelope object. All four now go through
  `TransportReply.envelopeObject()`/`envelopeList()`
  (`lib/src/core/http/login_flow_envelope.dart`), the one place every
  `/v1/user` route reads its `data`.
- Contract: device logout and global logout are CORS-enabled for browser
  first-party apps (server-side change, no library code change).

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
