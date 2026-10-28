# Design decisions of `loginflow_auth`

Each decision lists its normative source. Code comments point either to the
source directly (RFC/OIDC section) or to a decision here (`doc/decisions.md`
Dn). "Our choice" marks decisions no source makes for us.

## Sources

| Key | URL |
|---|---|
| RFC6749 | https://www.rfc-editor.org/rfc/rfc6749 |
| RFC6585 | https://www.rfc-editor.org/rfc/rfc6585 |
| RFC7009 | https://www.rfc-editor.org/rfc/rfc7009 |
| RFC7636 | https://www.rfc-editor.org/rfc/rfc7636 |
| RFC8252 | https://www.rfc-editor.org/rfc/rfc8252 |
| RFC8414 | https://www.rfc-editor.org/rfc/rfc8414 |
| RFC8693 | https://www.rfc-editor.org/rfc/rfc8693 |
| RFC8725 | https://www.rfc-editor.org/rfc/rfc8725 |
| RFC9110 | https://www.rfc-editor.org/rfc/rfc9110 |
| RFC9126 | https://www.rfc-editor.org/rfc/rfc9126 |
| RFC9207 | https://www.rfc-editor.org/rfc/rfc9207 |
| RFC9449 | https://www.rfc-editor.org/rfc/rfc9449 |
| RFC9470 | https://www.rfc-editor.org/rfc/rfc9470 |
| RFC9700 | https://www.rfc-editor.org/rfc/rfc9700 |
| OAUTH21 | https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1 |
| FIPA | https://datatracker.ietf.org/doc/html/draft-ietf-oauth-first-party-apps (draft-04) |
| BBA | https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps |
| OIDC-CORE | https://openid.net/specs/openid-connect-core-1_0.html |
| OIDC-DISC | https://openid.net/specs/openid-connect-discovery-1_0.html |
| OIDC-NSSO | https://openid.net/specs/openid-connect-native-sso-1_0.html (draft 07) |
| OIDC-RPI | https://openid.net/specs/openid-connect-rpinitiated-1_0.html |
| OIDC-CREATE | https://openid.net/specs/openid-connect-prompt-create-1_0.html |
| APPLE-KC-SHARE | https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps |
| APPLE-KC-AFU-TDO | https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly |
| APPLE-ASWAS | https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession |
| APPLE-ASWAS-EPHEMERAL | https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/prefersephemeralwebbrowsersession |
| A-MANIFEST | https://developer.android.com/guide/topics/manifest/manifest-element |
| A-SECTIPS | https://developer.android.com/privacy-and-security/security-tips |
| A-PERMDEF | https://developer.android.com/guide/topics/permissions/defining |
| A-BLOCKSTORE | https://developer.android.com/identity/block-store |
| A-KEYSTORE | https://developer.android.com/privacy-and-security/keystore |
| G-POLICIES | https://developers.google.com/identity/protocols/oauth2/policies |
| G-BP | https://developers.google.com/identity/protocols/oauth2/resources/best-practices |
| G-OIDC | https://developers.google.com/identity/openid-connect/openid-connect |
| G-ANDROID-SIWG | https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation |
| G-IOS-BACKEND | https://developers.google.com/identity/sign-in/ios/backend-auth |
| MS-NA-CHOOSE | https://learn.microsoft.com/en-us/entra/identity-platform/concept-choose-authentication-approach |
| MS-3PC | https://learn.microsoft.com/en-us/entra/identity-platform/reference-third-party-cookies-spas |
| MS-KEYROLL | https://learn.microsoft.com/en-us/entra/identity-platform/signing-key-rollover |
| MS-CLAIMSVAL | https://learn.microsoft.com/en-us/entra/identity-platform/claims-validation |

## Decisions

**D1 — Native sign-in through the Authorization Challenge Endpoint.**
First-party apps keep native screens but never call a credential endpoint
that returns tokens: the multi-step exchange ends in an authorization code
redeemed at `/token`. ROPC "MUST NOT be used" (RFC9700 §2.4; OAUTH21 §10).
FIPA §1, §3.1, §5, §6, Appendix C.

**D2 — PKCE S256 on every authorization; `plain` never.** RFC7636 §4.2;
RFC9700 §2.1.1; OAUTH21 §4.1.1. FIPA §5.1 makes `code_challenge` optional;
requiring it keeps one rule for all flows (our choice, allowed by FIPA).

**D3 — System browser only, never a WebView; claimed `https` redirects
preferred.** RFC8252 §6, §7.1, §7.2, §8.12; G-POLICIES ("Use secure
browsers"); APPLE-ASWAS (only the calling app receives the callback). The
ephemeral-session switch is set deliberately by the app
(APPLE-ASWAS-EPHEMERAL).

**D4 — Microsoft and sign-up (and Google without the native SDK)
continue in the browser (`redirect_to_web`).** FIPA §5.2.2.1.1, §9.2;
MS-NA-CHOOSE (social identity providers still use a browser window with
native authentication). Sign-up uses `prompt=create` (OIDC-CREATE).
Password reset does NOT (0.17.0): every authentication of a first-party app
happens in the app through this library, so the reset is the email-code
sign-in held back until `POST /v1/user/change-password` succeeds
(`LoginFlowAuth.startPasswordReset`), with the usual step-up when the
account needs a strong sign-in. `intent=password_reset` (FIPA App. A.2) is
no longer sent; only providers that force a browser keep one.

**D5 — Google natively with a server-issued nonce.** The ID token is
requested with `serverClientId` = the company's Google web client and the
nonce the server bound to the auth session, then posted as a challenge step;
the server validates it. G-ANDROID-SIWG ("the request and response nonces
are identical"); G-IOS-BACKEND; OIDC-CORE §3.1.3.7. The Google SDK lives in
an optional package so other apps do not depend on it (our choice).

**D6 — Every ID token is validated before any claim is used.** Signature
with the issuer key named by `kid`, `alg` ∈ {RS256, ES256} ∩ discovery,
`iss`, `aud`, `azp`, `exp`, `iat`, `nonce`, unchanged `sub` on refresh;
`typ: at+jwt` and `crit` are refused. OIDC-CORE §3.1.3.7, §12.2, §15.1
(RS256); RFC8725 §3.1, §3.10, §3.11.

**D7 — JWKS cached by `kid`; unknown `kid` refetched at most once a minute;
one fetch in flight.** OIDC-CORE §10.1.1; MS-KEYROLL (refresh on an unknown
`kid`, rate-limited).

**D8 — Discovery is strict.** The issuer is compared byte for byte
(OIDC-DISC §4.3; RFC8414 §3.3); issuer and endpoints must be `https`
(RFC6749 §3.1, §3.2; loopback `http` is accepted only for local development
and tests, our choice); `S256` must be advertised (RFC9700 §2.1.1);
`authorization_response_iss_parameter_supported` must be `true` and every
authorization response must carry a matching `iss` (RFC9207 §2.4;
RFC9700 §2.1, mix-up defence).

**D9 — Tokens.** Access tokens live in memory only. Refresh tokens rotate on
every use and are persisted before the new access token is used; one refresh
at a time; a rejected refresh (`invalid_grant`) clears the local session;
a refresh that finishes after the session it belonged to ended is discarded
and its token revoked. RFC9700 §2.2.2, §4.14.2. Stored secrets go to the
Keychain or Android Keystore-encrypted storage (G-BP; A-KEYSTORE).

**D10 — Flutter web.** Tokens in memory only; sign-in is a top-level
redirect (authorization code + PKCE, `prompt=none` first); no iframes and no
third-party cookies; the PKCE round-trip is kept in `sessionStorage` until
the callback. BBA §6.3; MS-3PC (iframe silent renew fails without
third-party cookies; use full-page redirects); OIDC-CORE §3.1.2.6.

**D11 — Native SSO between apps of the same publisher.** `device_sso`
scope; the first app stores `device_secret` + ID token in shared storage;
another app exchanges them for its own tokens; refresh tokens are never
shared and each app keeps its own `client_id`. OIDC-NSSO §3.1–§3.4, §4.1–§4.4;
RFC8693 §2.1, §3 (`urn:ietf:params:oauth:token-type:id_token`).

**D12 — Shared SSO storage.** iOS/macOS: a Keychain access group,
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, never synchronizable
(APPLE-KC-SHARE; APPLE-KC-AFU-TDO; OIDC-NSSO §6.2 device binding). Android:
a ContentProvider protected by a `signature` permission, plus a caller
certificate check, plus a check that the sibling provider belongs to a
package signed with the same certificate (A-SECTIPS; A-PERMDEF).
`sharedUserId` is deprecated (A-MANIFEST); Block Store is for restore on a
new device, not cross-app sharing (A-BLOCKSTORE).

**D13 — "Continue as …" before using Native SSO.** Native SSO does not prove
the same human holds the device (OIDC-NSSO §6.4); the confirmation is our
UX choice.

**D14 — Four logout levels.** App: revoke this app's refresh token
(RFC7009 §2) and clear local state. Device: end the `sid` on the server,
which invalidates every sibling refresh token (OIDC-NSSO §4.3; LoginFlow
extension endpoint). Browser: RP-initiated logout (OIDC-RPI §2, §3).
Everywhere: revoke every session of the user (RFC9700 §4.14.2 allows
revocation on logout; LoginFlow extension). Sibling apps learn at their next
refresh, so access tokens are short (15 min).

**D15 — Identity.** Key app data on (`company_id`, `sub`), never on email.
OIDC-CORE §2 (`sub` locally unique, never reassigned); G-OIDC ("Don't use
the email field as a unique identifier"); MS-CLAIMSVAL.

**D16 — Rate limiting and anti-enumeration.** 429 with `Retry-After`
(RFC6585 §4; RFC9110 §10.2.3); the same answers whether or not an account
exists; RFC6749 §10.10; FIPA §9.3.

**D17 — A pending browser request expires after 10 minutes.** An
authorization code must be short-lived, a maximum of 10 minutes is
recommended (RFC6749 §4.1.2); a callback for an older request is refused
(our choice of bound). A callback that does not target the pending
redirect URI with the pending `state` is ignored and the pending request is
kept (RFC6749 §10.12; RFC9700 §2.1).

**D18 — DPoP for native first-party clients.** FIPA §9.5 says tokens SHOULD
be sender-constrained and RFC9449 §5 binds refresh tokens of public clients.
The library holds a per-app key (`DpopKeyStore`) and attaches a proof
(`DpopProofFactory`) to every challenge, token and resource request of a
`native` + `first_party` client (`doc/server-contract.md` §13).

**D19 — The built-in UI shows only methods the app configured AND the
server allows for the client**, in the app's order (LoginFlow extension
`loginflow_login_options_endpoint`, `doc/server-contract.md` §4). Our design.

**D20 — Types that are values, not data models.** These types are never
serialized and are documented as such; they keep a `const` constructor,
`==` and `hashCode`:

- `LoginFlowError` and its subclasses: an error is an outcome to switch over
  exhaustively, not data to store or send; several wrap transient protocol
  objects. They have no `copyWith` because an error is never modified after
  it is produced.
- `AuthState` and its subclasses, `SignInState`, `SignInPhase`s: transient UI
  and flow state rebuilt from storage at start-up.
- Request payloads (`ChallengeInput`s, `ChallengeRequest`, `TokenGrant`s):
  serialized only to form fields; they may carry secrets and are never
  stored or parsed back.
- `TransportReply`, `CompactJws`, `ActiveSession`, `AuthorizationAttempt`,
  `UserAgentOutcome`s, `SignInEnvironment`: internal holders of a live
  object, an HTTP response or in-flight secrets.

**D21 — The server is the source of truth for a first-factor passkey
button, same as D19 for methods.** `ClientLoginOptions.hasPasskey`/
`passkeyMode` (`doc/server-contract.md` §4) decide whether "Continue with a
passkey" may appear at all: `passwordless` allows it,
`mfa_only`/`disabled` (the latter: no `passkey` field) never show it as a
first factor — a passkey second factor mid-challenge is unaffected, it
already runs automatically regardless of this flag.
`SignInConfiguration.isPasskeySignInOffered` defaults to `true` and may
only narrow this (hide a passkey the server allows), never widen it. Our
design, mirroring D19.

**D22 — i18n migrated to the house ARB pattern
(`flutter-i18n-offline`).** `lib/src/sign_in/l10n/arb/login_flow_{es,en}.arb`
are now the source of truth, compiled with `flutter gen-l10n`
(`l10n.yaml`) into `generated/login_flow_localizations*.dart`.
`LoginFlowStringsEn`/`Es` keep their existing shape (every widget already
reads `context.loginFlowStrings`, never a locale directly) but are now
thin delegates to the generated classes, so no widget changed. `es` is
the base/template locale (`template-arb-file`) per the user's decision;
adding a language is adding its `.arb` file and one line to
`LoginFlowLocaleService.supportedLocales` — no widget touches a locale
check. `flutter_localizations` moved from `dev_dependencies` to
`dependencies`: the file `flutter gen-l10n` generates imports it
unconditionally (for `GlobalMaterialLocalizations.delegate` et al. in its
`localizationsDelegates` helper, which we do not use but which the
generated file still references at the top level), and it ships with the
Flutter SDK at zero extra download cost — there is no `l10n.yaml` option
to omit that import. Completeness test:
`test/sign_in/l10n/login_flow_locale_test.dart`.

**D23 — Explicit locale override: `LoginFlowLocaleService`.** A new
service-mixin singleton (`ReactiveNotifier<Locale?>`, consistent with
`SignInService`'s existing pattern) resolves the effective locale in one
place: an explicit `LoginFlowLocaleService.setLocale(...)` call wins,
else the ambient `Localizations` locale, else `es`. `SignInPanel` wraps
itself in a `ReactiveBuilder<Locale?>` on this notifier (on top of the
`ReactiveViewModelBuilder` it already had) so a runtime language switch
reconstructs the built-in UI without the host app needing to pop/push
anything. No widget below `SignInPanel` branches on a locale; they all
still go through `context.loginFlowStrings`/`context.languageCode`, which
now reads `LoginFlowLocaleService.resolve(context)` instead of only the
ambient locale with a hardcoded `en` fallback. This is a user decision
(`es` is base, `en` second, more later — "adding a language = adding a
file").

**D24 — Per-app branding, including the legal-links footer.**
`LoginFlowSignInTheme` (a real `ThemeExtension`, `copyWith`/`lerp`/`==`/
`hashCode`) carries spacing, corner radius, card width, logo height,
action height, progress thickness and an optional `cardColor`; colors and
typography come from the host's `ColorScheme`/`TextTheme`, never
hardcoded. The logo is a `Widget?` passed in by the host app (asset,
`Image.network`, anything), not an asset path the library owns.
`SignInCopy.title`/`.subtitle` let the server override those two texts
per locale (`LocalizedText`).

Privacy-policy/terms-of-service: `ClientLoginOptions.policyUri`/`.tosUri`
parse the server's RFC 7591 `policy_uri`/`tos_uri`
(`doc/server-contract.md` §4) into `SignInState.policyUri`/`.tosUri`.
`SignInPanel` renders `SignInLegalFooter` below the current step only
when at least one is set — "Al continuar, aceptas los Términos y la
Política de privacidad", each configured link tappable, opening in the
system browser (`url_launcher`, `LaunchMode.externalApplication`), never
a `WebView` (RFC 8252 §8.12) and never through `ExternalUserAgent` (that
abstraction waits for an OAuth callback that a legal document never
sends). Texts are ARB (`legalFooterBoth`/`legalFooterTermsOnly`/
`legalFooterPolicyOnly`/`legalTermsLabel`/`legalPrivacyLabel`), styled
through the host's `TextTheme`/`ColorScheme`, same as every other text in
the UI.

**D25 — Goldens render without loading an extra test font.**
`test/goldens/` (one file per screen, `test/goldens/README.md` documents
the convention) renders every screen of the built-in sign-in UI through
the real public `LoginFlowSignIn` widget, with `SignInState` forced
directly on `SignInService.flow.notifier` via the ViewModel's own public
`updateState` — a golden tests pixels, not the authorization-challenge
flow (`sign_in_widget_test.dart` already covers that). No font is bundled
or loaded for determinism: `pubspec.yaml` declares no custom font, so
Flutter's test environment already renders every `Text` with its own
bundled, version-locked test font rather than a real one — already
deterministic across machines by construction, nothing to load. Verified:
the same 64 goldens pass unchanged across repeated `flutter test
test/goldens/` runs with no `--update-goldens`. A real bug was caught
while building the harness: forcing the state **before** `pumpWidget` is
silently overwritten by `ViewModel.init()`, which runs when the first
consumer widget mounts and resets to `SignInNotConfigured` (no environment
installed) — every screen rendered as the "not configured" message until
the state is forced **after** `pumpWidget`, with one more `pump()`.

**D26 — Exhaustive review of `doc/server-contract.md` against
`loginflow_auth` and the real server (`../loginflow_api`,
`feat/oidc-provider-cutover`).** Section by section: §1 general
rules, §2 discovery, §3 JWKS, §4 login options, §5 authorization challenge
(steps, errors, anti-enumeration, upstream validation, passkeys/TAP), §6
browser authorization endpoint, §7 token endpoint (all three grants,
response, errors), §8 token claims, §9 revocation, §10/§11 device/global
logout, §12 RP-initiated logout, §13 DPoP, §15 passkey account API. The
client already matched the contract everywhere checked — no library change
was needed. Every divergence found was on the **server** side, all four
fixed on `loginflow_api` (`feat/oidc-provider-cutover`):

- **Discovery now publishes `authorization_response_iss_parameter_supported:
  true` and `native_sso_supported: true`**
  (`loginflow_api src/features/oidc_provider/service/discovery_document.rs::build`).
  `discovery_client.dart:94` no longer refuses the document
  (`DiscoveryInvalid`); native sign-in completes against the real server.
  The authorization success response (hosted and native) already carried
  `iss` (RFC 9207 §2, `authorization_service.rs::success_redirect`) — no
  change needed there. `tests/discovery_document_test.rs` asserts both
  booleans.
- **`GET /oauth2/login-options` now serializes the typed
  `LoginOptionsResolution` through a thin `LoginOptionsResponse` wrapper**
  (`#[serde(flatten)]`, `client_id` echoed alongside it) instead of a
  hand-built `json!({...})` — `facebook_app_id` is included when resolved,
  and `passkey_mode`/`google_server_client_id`/`facebook_app_id` are
  OMITTED, never `null`, when absent (contract §4).
  `tests/login_options_wire_shape_test.rs` asserts the exact shape.
- **`/oauth2/device-logout` and `/oauth2/logout-everywhere` now accept
  `Authorization: DPoP <token>` with a matching proof** (contract §13.3),
  the same split `authenticate_access` (`shared/helper/jwt_middleware.rs`)
  already enforced on `/v1/user` and the panel's routes — extracted to a shared, pure
  `dpop_service::classify_resource_authorization` both now call, so the
  decision logic lives in one place. A DPoP-bound token presented as
  `Bearer` is rejected (`invalid_dpop_proof`); a non-bound token keeps
  working as plain `Bearer`, unchanged. `SessionService::device_logout`/
  `logout_everywhere` take the caller's scheme/proof/`htm`/`htu` and run
  the same check `TokenEndpointService` already uses for `/oauth2/token`.
  `tests/dpop_resource_classification_test.rs` covers the pure
  classification; `session_handler.rs` wires the HTTP boundary.

Nothing in `loginflow_auth` itself needed a line changed by this review —
the library already enforces every rule above (refusing the bad
discovery document, sending `DPoP` not `Bearer`, reading `client_id`-only
revocation correctly, etc.); the findings are all on the server side of
the line.

**D27 — Access codes in the bundled UI are an app opt-in, and the
passkey manager reuses the sign-in steps for its step-up.** (The
"nothing to intersect with" part is superseded by D28.) The server's
login options never advertised `access_code` then (it was not a client
login method), so unlike D19 there was nothing to intersect with:
`SignInConfiguration.isAccessCodeOffered` decided whether the entry
appears, and the server stays the authority by refusing
(`access_codes_disabled` → `AccessCodesUnavailable`). With no
other method, the access-code step is the entry screen, so a kiosk or
driver app needs no picker. The code's shape is checked locally before
the request, so a typo never counts against the server's per-key and
per-application failure thresholds.

`LoginFlowPasskeys` handles `StepUpRequired` exactly as `enrollPasskey`
documents (`stepUp(requirement)`, then one retry). The step the server asks
for is rendered by the sign-in UI's own `SignInStepView`, driven by
`SignInViewModel`, which already follows every `ChallengeRequired` with
`purpose: stepUp` — no second set of password/TOTP/OTP widgets. The manager
tells a completed step-up from a cancelled one by the session it ends in:
a cancel returns to the resting `SignedIn` with the SAME session, a
completed step-up yields a new one (new ID token: new `sid`, later
`auth_time`). Only the latter retries, and only once; a second
`StepUpRequired` is shown as a message, never looped. Our design.

**D28 — `access_code` is a client login method; every principal may hold
a passkey.** `loginflow_api` now lists `access_code` among a client's
`login_methods` and refuses a redemption from a client without it
(`unauthorized_client`). The bundled UI therefore intersects like D19:
"I have an access code" needs the app's opt-in **and**
`ClientLoginOptions.isAccessCodeOffered`, and it stays an entry of its
own, never an `AuthMethod` button (a code is redeemed, not chosen). The
server also lets access-code subjects own passkeys, `person` and
`device` alike, so the passkey manager no longer refuses a `device`
(`PasskeysState.isEnrollmentOffered` is gone) and its default account
name for a subject is the server's: display name, else external id. A
coded `403` from the passkey account API is `PasskeyAccountRefused(code)`
— the code is kept verbatim, not an enum, because it names a server-side
policy the app only needs to log and route around. A passkey sign-in the
server refuses after the ceremony (`webauthn_assertion` with a
`step_error`) is `PasskeyRejected` and ends the attempt: the WebAuthn
challenge is single-use, so running the ceremony again on that step could
never succeed, and an app with a fallback (an access code) needs a
terminal, typed answer to switch to it.
