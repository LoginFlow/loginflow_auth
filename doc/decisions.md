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

**D4 — Microsoft, sign-up, password reset (and Google without the native
SDK) continue in the browser (`redirect_to_web`).** FIPA §5.2.2.1.1, §9.2,
Appendix A.2; MS-NA-CHOOSE (social identity providers still use a browser
window with native authentication). Sign-up uses `prompt=create`
(OIDC-CREATE).

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

**D18 — DPoP is deferred.** FIPA §9.5 says tokens SHOULD be
sender-constrained and RFC9449 §5 binds refresh tokens of public clients.
0.1.0 does not send DPoP proofs; the server must not require them until the
library ships per-app hardware-backed keys. Open decision.

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
