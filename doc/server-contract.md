# LoginFlow server contract for `loginflow_auth` 0.1.0

This document is the HTTP contract the Flutter library relies on. The server
(phases 5 and 5b of `loginflow_api`) implements exactly this. Where a standard
leaves a choice to the deployment, the choice made for LoginFlow is stated and
marked **LoginFlow profile**. Anything marked **LoginFlow extension** is not
defined by any standard.

The key words MUST, MUST NOT, SHOULD, MAY are used as in RFC 2119.

## 0. References

| Key | Document |
|---|---|
| RFC6749 | OAuth 2.0 Authorization Framework |
| RFC6750 | Bearer Token Usage |
| RFC7009 | Token Revocation |
| RFC7517 / RFC7518 | JSON Web Key / JSON Web Algorithms |
| RFC7636 | PKCE |
| RFC8252 | OAuth 2.0 for Native Apps (BCP 212) |
| RFC8414 | Authorization Server Metadata |
| RFC8693 | Token Exchange |
| RFC8725 | JWT Best Current Practices |
| RFC9126 | Pushed Authorization Requests |
| RFC9207 | Authorization Server Issuer Identification |
| RFC9470 | Step-up Authentication Challenge |
| RFC9700 | OAuth 2.0 Security BCP (BCP 240) |
| FIPA | draft-ietf-oauth-first-party-apps-04 (Authorization Challenge Endpoint) |
| OIDC-CORE | OpenID Connect Core 1.0 |
| OIDC-DISC | OpenID Connect Discovery 1.0 |
| OIDC-NSSO | OpenID Connect Native SSO for Mobile Apps 1.0, draft 07 |
| OIDC-RPI | OpenID Connect RP-Initiated Logout 1.0 |
| OIDC-CREATE | Initiating User Registration via OpenID Connect 1.0 (`prompt=create`) |

FIPA and OIDC-NSSO are drafts: parameter names can change before they become
final. When they do, this contract and the library change together.

Issuers: production `https://api.loginflow.dev`, development
`https://api-dev.loginflow.dev`. Paths below are recommendations; the library
reads every endpoint from discovery and never builds a path itself.

## 1. General rules

1. Every endpoint is HTTPS (RFC6749 §3.1, §3.2).
2. Every JSON response sets `Content-Type: application/json`.
3. Every response that carries a code, token, `auth_session`, `device_secret`
   or credential-related error sets `Cache-Control: no-store`
   (RFC6749 §5.1, FIPA §5.2).
4. POST bodies are `application/x-www-form-urlencoded` (RFC6749 §3.2,
   FIPA §4.1).
5. Error bodies follow RFC6749 §5.2: `{"error", "error_description"?,
   "error_uri"?}`. `error_description` never contains secrets or tells
   whether an account exists.
6. Rate limiting answers **429** with a `Retry-After` header in seconds
   (delta-seconds form). The library shows a lockout countdown from it; when
   the header is missing it waits 30 s. The 429 body may be any JSON object.
   Lockouts per account use the same 429, so the response does not reveal
   whether the account exists (RFC6749 §10.10, FIPA §9.3).
7. CORS: allowed on discovery, JWKS, token, revocation, the login options
   endpoint, device logout and global logout, and on the REST scopes `/v1/user`, `/v1/app` and the panel's,
   for the server's configured origins (`CORS_ALLOWED_ORIGINS`); never on
   `/oauth2/authorize` (RFC9700 §2.6). Those endpoints allow the request
   headers `Authorization, Content-Type, Accept, X-Requested-With, DPoP` and
   expose `DPoP-Nonce, WWW-Authenticate, Retry-After, X-Request-Id,
   X-Total-Count`, so a browser app can send a DPoP proof (§13) and read the
   nonce to retry with and the `Bearer`/`DPoP` challenge of a refused token.
   `userinfo` is not CORS-enabled. Device logout and global logout are, because
   a browser first-party app (§13) signs out through them with its DPoP-bound
   access token; they accept no cookie, so a cross-site page cannot trigger them. The authorization
   challenge endpoint (§5) is CORS-enabled **only** for the exact browser
   origins a first-party client registered (`allowed_web_origins`,
   **LoginFlow profile**, opt-in per client): the preflight is granted
   (`Access-Control-Allow-Origin: <origin>`, methods `POST`, headers
   `Content-Type, DPoP`, exposed `DPoP-Nonce, Retry-After`) when the origin
   belongs to some active first-party client; the actual request is then held
   to its own client (§5.1). Never `Access-Control-Allow-Credentials`: the
   challenge uses no cookie. A request without `Origin` (a native app) is
   unaffected.

## 2. Discovery: `GET /.well-known/openid-configuration`

Served also at `/.well-known/oauth-authorization-server` with the same body
(RFC8414 §3). `Cache-Control: public, max-age=<seconds>`; the library honours
`max-age` (1 h when absent).

The library **refuses** the document (no request is made to any endpoint) when:

- `issuer` is not byte-for-byte the configured issuer (OIDC-DISC §4.3);
- `code_challenge_methods_supported` lacks `S256` (RFC9700 §2.1.1);
- any endpoint below is not `https`.

| Field | Required by the library | Value |
|---|---|---|
| `issuer` | yes | `https://api.loginflow.dev` (no trailing slash) |
| `authorization_endpoint` | yes | e.g. `{issuer}/oauth2/authorize` |
| `token_endpoint` | yes | e.g. `{issuer}/oauth2/token` |
| `jwks_uri` | yes | e.g. `{issuer}/oauth2/jwks` |
| `id_token_signing_alg_values_supported` | yes | `["RS256","ES256"]` (RS256 MUST be listed, OIDC-DISC §3) |
| `code_challenge_methods_supported` | yes | `["S256"]` only |
| `response_types_supported` | OIDC-DISC | `["code"]` |
| `subject_types_supported` | OIDC-DISC | `["public"]` |
| `grant_types_supported` | for Native SSO | `["authorization_code","refresh_token","client_credentials","urn:ietf:params:oauth:grant-type:token-exchange"]` |
| `token_endpoint_auth_methods_supported` | — | must include `none` (public clients) |
| `authorization_challenge_endpoint` | for native sign-in | e.g. `{issuer}/oauth2/authorize-challenge` (FIPA §8) |
| `revocation_endpoint` | for app logout | e.g. `{issuer}/oauth2/revoke` |
| `end_session_endpoint` | for browser logout | e.g. `{issuer}/oauth2/end-session` |
| `authorization_response_iss_parameter_supported` | yes, `true` | RFC9207 §3 |
| `native_sso_supported` | for Native SSO | `true` (OIDC-NSSO §5) |
| `scopes_supported` | — | include `openid`, `profile`, `email`, `offline_access`, `device_sso` |
| `prompt_values_supported` | — | include `none`, `login`, `create` |
| `loginflow_login_options_endpoint` | for the built-in UI | **LoginFlow extension**, §4 |
| `loginflow_device_logout_endpoint` | for device logout | **LoginFlow extension**, §10 |
| `loginflow_global_logout_endpoint` | for "everywhere" logout | **LoginFlow extension**, §11 |
| `organizations_endpoint` | for organizations | **LoginFlow extension**, §17 |

The library requests `device_sso` only when `native_sso_supported` is `true`
and the app enabled Native SSO.

## 3. JWKS: `GET {jwks_uri}`

- RFC7517 §5 key set. One RSA key (≥ 2048 bits) with `alg: "RS256"`, one EC
  P-256 key with `alg: "ES256"`, each with a unique `kid` and `use: "sig"`.
  One algorithm per key (RFC8725 §3.1).
- `Cache-Control: public, max-age=21600` (6 h). The library honours the
  value it receives and assumes no other lifetime.
- Rotation: publish the next key **before** signing with it, at least one
  `max-age` earlier; keep a retired key published at least
  (longest ID token lifetime + `max-age`) (OIDC-CORE §10.1.1).
- The library caches by `kid` and refetches on an unknown `kid` at most once
  per minute. Unknown key types in the set are ignored, not fatal.

## 4. Login options: `GET {loginflow_login_options_endpoint}?client_id=…`

**LoginFlow extension.** Public, unauthenticated, cacheable
(`Cache-Control: public, max-age=300` recommended). It tells the built-in UI
which primary methods the server allows for this client, so a method that
the server does not allow is never shown.

```json
{
  "client_id": "turnosqr-mobile",
  "login_methods": ["password", "email_otp", "google", "microsoft", "apple", "facebook"],
  "self_signup": true,
  "password_reset": true,
  "passkey": true,
  "passkey_mode": "passwordless",
  "google_server_client_id": "1234567890-abc.apps.googleusercontent.com",
  "facebook_app_id": "1234567890123456",
  "policy_uri": "https://acme.example/privacy",
  "tos_uri": "https://acme.example/terms"
}
```

- `client_id` MUST echo the request (the library rejects a mismatch).
- `login_methods` wire names: `password`, `email_otp`, `google`,
  `microsoft`, `apple`, `facebook`. A name only appears when the client is
  configured for it **and** the company/application actually has it usable
  (for `google`/`microsoft`/`apple`/`facebook`, an enabled upstream
  provider config). Unknown future names are ignored by older libraries.
  TOTP is not a primary method; it appears as a challenge step (§5).
  `passkey` is never a member of this array (see below) and a Temporary
  Access Pass is never advertised here — it is admin-issued, not
  client-selected.
- `self_signup`: the application's `allow_self_signup` flag.
- `password_reset`: whether the hosted reset flow is enabled for the client.
- `passkey`: `true` when the company's passkey policy (company-wide, set by
  the company's admin or by LoginFlow's master operators — never per end
  user) is not `disabled`; absent fields `passkey_mode`/
  `google_server_client_id` are omitted, not `null`, when not applicable.
- `passkey_mode` (present only when `passkey` is `true`): `"mfa_only"` —
  the passkey may stand in for the second factor on top of a primary
  method — or `"passwordless"` — it may also be the first factor on its
  own. Drives whether the built-in UI offers "Sign in with a passkey" as a
  first-factor option.
- `google_server_client_id` (present only when `google` is configured and
  enabled): the Google OAuth client ID a native app needs for
  `CredentialManager`'s `GetGoogleIdOption` / `GoogleSignInOptions`. Not a
  secret.
- `facebook_app_id` (present only when `facebook` is configured and
  enabled): the Facebook App ID a native app needs for the Facebook SDK.
  Not a secret. Apple needs no equivalent field here: the native ceremony
  resolves entirely from the app's own Xcode capability and bundle/Services
  ID, never from a value the server hands out per request.
- `policy_uri`/`tos_uri` (RFC 7591 client-metadata names): the company's
  privacy-policy/terms-of-service pages, each an `https` URL. Both are
  optional and are omitted, not `null`, when the company has not
  configured one; the library's built-in UI shows a link only for the
  one(s) present, and nothing when neither is. A value that is present
  but not `https` is treated by the library the same as absent.
- Unknown `client_id`: `404 {"error":"invalid_client"}`.

## 5. Authorization Challenge Endpoint: `POST {authorization_challenge_endpoint}`

FIPA §4–§7 with the **LoginFlow profile** below.

### 5.1 Who may call it

Only clients registered `public` + `native` + `first_party = true`
(FIPA §1.1, §9.1). Others: `400 {"error":"unauthorized_client"}`. Public
clients identify themselves with `client_id`; no client secret is accepted
(RFC8252 §8.4–8.5).

**LoginFlow profile — first-party web apps.** A `first_party` client that
runs in a browser registers its exact origins (`allowed_web_origins`,
`https://host[:port]`). A request that carries an `Origin` header is only
served when that origin is in the `allowed_web_origins` of the request's own
client (`client_id` on the opening request, the authorization's client on a
continuation); otherwise `400 {"error":"unauthorized_client"}` with no CORS
header (§1.7). Every method, passkeys included (§5.7), works the same from
such an origin.

### 5.2 Authorizations and requests

An *authorization* is one attempt to obtain one authorization code. It is
opened by a request that carries the authorization parameters (§5.3); the
server binds them to an `auth_session` and returns it. Later requests of the
same authorization carry `auth_session` and step parameters only.

A request that carries authorization parameters **and** an `auth_session`
opens a new authorization on an existing session: that is step-up (FIPA §7)
and re-authentication after a refresh (FIPA §6.2). The server MUST then
require the new `code_challenge` at the token endpoint for the new code.

Every request carries:

| Parameter | Rule |
|---|---|
| `client_id` | REQUIRED |
| `response_type` | REQUIRED, `code` (FIPA §5.1) |
| `auth_session` | REQUIRED on every request after the first of a session |

### 5.3 Authorization parameters (opening request only)

| Parameter | Rule |
|---|---|
| `scope` | REQUIRED; space-separated; includes `openid offline_access`, plus `device_sso` when Native SSO is enabled, plus app scopes |
| `code_challenge` | REQUIRED in the LoginFlow profile (FIPA §5.1 makes it optional; RFC9700 §2.1.1); 43 chars base64url |
| `code_challenge_method` | REQUIRED, `S256` only; `plain` → `invalid_request` |
| `nonce` | REQUIRED when `openid` is requested; echoed in the ID token (OIDC-CORE §3.1.2.1) |
| `redirect_uri` | OPTIONAL; sent when the app has a browser fallback. Exact match against the client's registered URIs (RFC9700 §4.1.3). Used **only** if the server answers `redirect_to_web` with a `request_uri`; it is then part of the pushed request |
| `state` | OPTIONAL; sent with `redirect_uri`; returned on the browser redirect |
| `acr_values` | OPTIONAL; step-up requirement (RFC9470 §4) |
| `max_age` | OPTIONAL; seconds (OIDC-CORE §3.1.2.1) |
| `prompt` | OPTIONAL; `create` = sign-up (OIDC-CREATE), always answered with `redirect_to_web` |
| `ui_locales` | OPTIONAL; e.g. `es en`; language of the email OTP and hosted pages |
| `id_token_hint` | OPTIONAL; identifies the user for a step-up without `auth_session` (OIDC-CORE §3.1.2.1). It **only identifies** the user and is never a primary factor: the server answers the primary step that applies (e.g. `next: password`), never an authorization code |
| `organization` | OPTIONAL; **LoginFlow extension**, the organization id the session starts in (§17). An organization of another application → `400 invalid_request`. A step-up sends the session's organization |

A missing `code_challenge` on an opening request → `400 invalid_request`.

### 5.4 Step parameters (LoginFlow profile, FIPA §5.1 and Appendix B)

| Parameter | Meaning |
|---|---|
| `login_hint` | The identifier (email). MAY come together with `password` or `method` in the same request |
| `password` | Password for `login_hint` (or for the session's user) |
| `method` | `email_otp` → the server sends the code as a side effect and answers `next: email_otp` (FIPA App. A.4); `password` → answers `next: password` |
| `email_otp` | The emailed code |
| `resend` | `email_otp` → send a new code, answer `next: email_otp` |
| `totp` | 6-digit TOTP |
| `recovery_code` | A TOTP recovery code (single use) |
| `upstream_provider` | `google`, `microsoft`, `apple` or `facebook` |
| `upstream_flow` | `native` (the app will post an `upstream_token`; Microsoft never sends this, it is always `browser`) or `browser` (answered with `redirect_to_web`) |
| `upstream_token` | The provider token (with the matching `upstream_provider`), typed by `upstream_token_type` |
| `upstream_token_type` | `id_token` (Google always; Apple always; Facebook iOS Limited Login) or `access_token` (Facebook Android classic login) — **LoginFlow extension**, generalizing the single implicit `id_token` Google used before Apple/Facebook existed |
| `upstream_user_name` | **LoginFlow extension.** Apple's given/family name (e.g. `"Ana Ruiz"`), sent only on the first authorization for that Apple ID + app pair — Apple omits it from every later `identityToken`, so the library forwards whatever it received instead of caching it client-side |
| `intent` | `password_reset` → `redirect_to_web` to the hosted reset flow (FIPA App. A.2); MAY carry `login_hint` |
| `method` (passkeys) | `webauthn_identify` → starts a passkey ceremony: targeted when sent together with `login_hint`, discoverable/conditional otherwise. Answers `next: webauthn_assertion` with `options` (§5.7) |
| `webauthn_assertion` | **LoginFlow extension.** The raw `PublicKeyCredential` JSON from `navigator.credentials.get()`, JSON-encoded as a single form field (nested JSON has no native form-urlencoded shape). A valid assertion satisfies both the primary method and the second factor in the same step |
| `temporary_access_pass` | **LoginFlow extension.** An admin-issued, single-use recovery code, identified by `login_hint` like `password`. Also satisfies both factors in one step, but is never phishing-resistant |
| `method` (access codes) + `access_code` | **LoginFlow extension.** `method=access_code` with `access_code=<normalized code>` in the opening request: a single-use code a tenant backend issued for one of its own subjects. Answered in one leg, never with a `next` (§16) |

### 5.5 Responses

**Success — `200`** (FIPA §5.2.1):

```json
{ "authorization_code": "…" }
```

The code: single use, lifetime ≤ 60 s, bound to `client_id`, the
`code_challenge` of its authorization, `nonce`, `scope`, the user, and **no**
`redirect_uri` (FIPA §6). Reuse of a code revokes the tokens issued from it
(RFC6749 §4.1.2).

**Opening request with no method — `403`.** An opening request that carries
no step parameter (no `password`, `method`, `email_otp`, `totp`,
`recovery_code`, `upstream_provider`), with or without `login_hint`, and no
`id_token_hint`, answers `insufficient_authorization` with
`next: select_method` and `methods` = the client's primary methods, using the
wire names of §4 (`password`, `email_otp`, `google`, `microsoft`, `apple`,
`facebook`). The client continues with `method=password` /
`method=email_otp`, or opens
`upstream_provider=google|microsoft|apple|facebook`. The status is 403,
not 200: FIPA §5.2.2
requires 403 for `insufficient_authorization`, and 200 is reserved for the
`authorization_code` response (§5.2.1).

**More steps — `403`** (FIPA §5.2.2, `insufficient_authorization` MUST be 403):

```json
{
  "error": "insufficient_authorization",
  "auth_session": "…",
  "next": "password | email_otp | totp | recovery_code | select_method | upstream_token",
  "methods": ["totp", "recovery_code"],
  "step_error": "invalid_credential | code_expired",
  "upstream": { "provider": "google", "nonce": "…", "client_id": "…apps.googleusercontent.com" }
}
```

- `auth_session`: REQUIRED in every 403; ≥ 256 bits random, opaque, stored
  server-side, replaces any previous value (FIPA §5.3.1, §9.6.2). Bound to the
  client and, once known, to the user. Lifetime: short while signing in; kept
  longer after the code is issued for step-up (FIPA §5.3.1; the duration is an
  open point, our choice).
- `next`: REQUIRED. An unknown value makes the library fail the attempt, so
  new step names need a library release.
- `methods`: alternatives the user may switch to (`select_method` choices;
  `["totp","recovery_code"]` on a TOTP step). Unknown names are ignored by the
  client.
- `step_error`: present when the previous step input was refused.
  `invalid_credential` for a wrong password/OTP/TOTP/recovery code;
  `code_expired` for an expired or burned email OTP (burned after 5 failures).
  The same value is returned whether or not the account exists.
- `upstream`: REQUIRED when `next = upstream_token`. `nonce` is generated by
  the server, bound to the `auth_session`, single use. For `provider:
  "google"`, `client_id` is the company's Google **web** client ID, passed
  to the Google SDK as `serverClientId`; for `provider: "apple"` or
  `"facebook"`, `client_id` is informational only (the Services ID / App
  ID the server has configured) — the native ceremony on the client side
  resolves its own provider client ID from app configuration (Xcode
  capability, `Info.plist`, Facebook SDK resources), never from this field.

Anti-enumeration: the answer to an identifier (with or without password)
MUST NOT depend on whether the account exists. A request with
`login_hint` + `method=email_otp` always answers `next: email_otp`; a request
with `login_hint` + wrong `password` always answers `next: password` with
`step_error: invalid_credential`, including for unknown accounts (with a dummy
password hash so timing does not leak).

TOTP: when the account has TOTP enabled, or the authorization's `acr_values`
requires it, a correct first factor is followed by `next: totp`. The library
shows the TOTP screen automatically.

**Continue in the browser — `403`** (FIPA §5.2.2.1.1):

```json
{
  "error": "redirect_to_web",
  "auth_session": "…",
  "request_uri": "urn:ietf:params:oauth:request_uri:…",
  "expires_in": 60
}
```

Used for Microsoft (always), Google/Apple/Facebook with
`upstream_flow=browser`, `prompt=create`, `intent=password_reset`, and any
risk-based decision (FIPA §9.2). A client sends `upstream_flow=browser`
for a provider whenever it has no native source registered for it, or that
source reports itself unavailable on the current platform (e.g. Apple on
Android) — the client decision, not a server one; the server does not
otherwise distinguish Apple/Facebook's `browser` leg from Google's.
`request_uri` references an internal pushed authorization
request (RFC9126 §2.2) built from the authorization's bound parameters,
including `redirect_uri`, `state`, `nonce`, `code_challenge` and `scope`. It
is single use and expires in `expires_in` seconds. Without a PKCE challenge
the server MUST NOT return a `request_uri` (FIPA §5.2.2.1.1).

When `request_uri` is absent, the library builds a full authorization request
itself (§6) with the same `state`, `nonce` and `code_challenge`.

**Session gone — `400`**:

```json
{ "error": "invalid_session" }
```

The library discards the attempt and shows "start again".

**Other `400`** (RFC6749 §5.2): `invalid_request`, `invalid_client`,
`unauthorized_client`, `invalid_scope`. **`429`**: §1.

### 5.6 Google upstream validation (server side)

Before accepting `upstream_token` the server MUST verify (G-ANDROID-SIWG,
G-IOS-BACKEND, OIDC-CORE §3.1.3.7): signature against Google's JWKS; `iss` ∈
{`https://accounts.google.com`, `accounts.google.com`}; `aud` = the configured
web client ID; `exp`; `nonce` = the `upstream.nonce` issued for this
`auth_session` (then burn it). Link accounts by Google `sub`; auto-link by
email only when Google is authoritative (`@gmail.com`, or `email_verified` and
`hd`) (`doc/decisions.md` D15, D16).

### 5.6b Apple and Facebook upstream validation (server side)

`upstream_token_type` tells the server which shape to expect; a mismatch
with what `upstream_provider` can actually produce (e.g. `apple` with
`access_token`) → the generic `insufficient_authorization`/
`invalid_credential` shape of §5.5, same as a wrong password.

- **Apple, `id_token`** (Sign in with Apple REST API): signature against
  Apple's JWKS (`https://appleid.apple.com/auth/keys`); `iss` =
  `https://appleid.apple.com`; `aud` = the company's registered Services ID
  (or app bundle ID for the native flow); `exp`; `nonce` = the lowercase hex SHA-256 of the `upstream.nonce` issued
  for this `auth_session`, compared byte for byte (the app passes that digest
  to `ASAuthorizationAppleIDRequest.nonce` and Apple returns it unchanged in
  the `identityToken`'s `nonce` claim; Google and Facebook return the raw
  value instead, which the server digests on arrival).
  Link accounts by Apple's `sub`. `upstream_user_name`, when present, is
  trusted only on the account's first-ever Apple link (Apple does not
  resend it afterward, so a later request can neither confirm nor
  contradict it).
- **Facebook, `id_token`** (Limited Login, iOS): verify as an OIDC token
  against `https://www.facebook.com/.well-known/oauth/openid/jwks/`; `iss`
  = `https://www.facebook.com`; `aud` = the company's Facebook App ID;
  `exp`; `nonce` = the raw `upstream.nonce` issued for this `auth_session`
  (then burn it) — same direction as Google.
  (G-FB-LIMITED-LOGIN style, no first-party-apps analogue exists)
- **Facebook, `access_token`** (classic login, Android): call Facebook's
  Graph API `/me` (or `/debug_token`) with the token to resolve the
  Facebook user id and confirm the token's `app_id` matches the company's
  Facebook App ID. No `nonce` to check — classic access tokens carry none;
  the LoginFlow extension that types this leg via `upstream_token_type`
  exists precisely so the server knows not to look for one.
- **Server implementation note (as shipped):** the NATIVE leg links by the stored
  `(provider, sub)` `oauth_identities` row, the SAME lookup the HOSTED browser flow uses
  (`GoogleClientResolver::resolve_upstream_identity`, backed by
  `upstream_authorization_service::resolve_upstream_account`) — one identity-resolution rule
  shared by both transports, not a per-transport difference. The upstream-verified EMAIL only
  enters when there is NO existing `oauth_identities` row yet for that subject, and only to
  auto-link (or create) an account, per the provider's own rule: Google auto-links whenever
  `email_verified`; Apple auto-links only when `email_verified` AND the address is not a
  `is_private_email` relay; Facebook NEVER auto-links (no claim ever vouches for its email). An
  identity ALREADY linked by `sub` (through either transport, or a prior link made by another
  method) signs in regardless of what its current email claim is — a changed Google/Apple email,
  or a Facebook/relay identity that can never auto-link, both still match by subject once linked.

### 5.7 Passkeys and Temporary Access Pass (LoginFlow extension, WebAuthn L3)

`method=webauthn_identify` answers `403`:

```json
{
  "error": "insufficient_authorization",
  "next": "webauthn_assertion",
  "auth_session": "…",
  "options": { "…": "webauthn-rs's RequestChallengeResponse, unmodified" }
}
```

`options` is passed straight to `navigator.credentials.get()` (or the
platform equivalent, `PasskeyAuthenticator.getAssertion`); the result comes
back as the `webauthn_assertion` form field above. A failed assertion
answers the generic `insufficient_authorization`/`invalid_credential` shape
**without** a fresh `options` member — a WebAuthn challenge is single-use,
so the library does not retry the ceremony blindly; it ends the attempt and
the caller starts over with a new `webauthn_identify` request.

`temporary_access_pass` answers the generic `insufficient_authorization`/
`invalid_credential` shape on a wrong or already-used code — no extra data
needed, the caller may retry with another code on the same `auth_session`.

Both methods, on success, satisfy the primary method AND the second factor
in the same step (a passkey is possession + user verification; a TAP is an
admin-issued credential), so neither is ever followed by `next: totp`.

**Related origins (WebAuthn L3, LoginFlow profile).** The RP ID is the
company's (`<slug>.id.loginflow.dev` or its custom domain), so a first-party
web app on another origin (§5.1) runs the ceremony against that RP ID as a
related origin: the browser fetches `https://<rp_id>/.well-known/webauthn`,
which lists `{"origins": [...]}` — the `allowed_web_origins` of the company's
active first-party clients — and the server verifies the assertion's
`clientDataJSON.origin` against the company's RP origin plus the requesting
client's `allowed_web_origins`. A browser without Related Origin Requests
support refuses the ceremony on the client side.

## 6. Authorization endpoint (browser): `GET {authorization_endpoint}`

Used by `redirect_to_web` and by Flutter web (top-level redirect).

Pushed form (RFC9126 §4): `?client_id=…&request_uri=…`.

Full form (RFC6749 §4.1.1, RFC7636 §4.3, OIDC-CORE §3.1.2.1):
`response_type=code`, `client_id`, `redirect_uri`, `scope`, `state`, `nonce`,
`code_challenge`, `code_challenge_method=S256`, optional `prompt`
(`none` | `login` | `create` | `select_account`), `login_hint` and
`organization` (§17).

- `redirect_uri` exact match; on an invalid `client_id`/`redirect_uri` show an
  error page and never redirect (RFC6749 §4.1.2.1).
- The redirect back MUST carry `iss` (RFC9207 §2) and `state`. The library
  rejects a callback whose `iss` differs or is missing, or whose `state`
  differs, before redeeming anything.
- `prompt=none` without a usable session: redirect with
  `error=login_required` (or `interaction_required`, `consent_required`,
  `account_selection_required`) + `state` + `iss` (OIDC-CORE §3.1.2.6). The
  library then offers the interactive sign-in.
- Codes from this endpoint are bound to the `redirect_uri`; the token request
  then MUST include the same `redirect_uri` (RFC6749 §4.1.3).

## 7. Token endpoint: `POST {token_endpoint}`

Public clients authenticate with `client_id` only
(`token_endpoint_auth_method=none`, RFC6749 §3.2.1). Always
`Cache-Control: no-store`.

### 7.1 `grant_type=authorization_code`

| Parameter | Rule |
|---|---|
| `code` | REQUIRED |
| `code_verifier` | REQUIRED; `BASE64URL(SHA256(code_verifier)) == code_challenge` (RFC7636 §4.6); a verifier for a code issued without a challenge → `invalid_grant` (downgrade protection, RFC9700 §2.1.1) |
| `client_id` | REQUIRED; must equal the code's client |
| `redirect_uri` | REQUIRED iff the code was issued through a browser redirect (§6), and then equal to it; absent for codes from the challenge endpoint (FIPA §6) |
| `device_secret` | OPTIONAL; the client MUST send it when it holds one (OIDC-NSSO §3.3). An invalid one is treated as absent (§3.4) |

### 7.2 `grant_type=refresh_token`

| Parameter | Rule |
|---|---|
| `refresh_token` | REQUIRED |
| `client_id` | REQUIRED; must equal the token's client |
| `device_secret` | OPTIONAL; SHOULD be sent so it can be rotated (OIDC-NSSO §3.3) |
| `resource` | OPTIONAL; the audience of the API the access token is for (RFC8707 §2, §17). Not one of the client's APIs → `400 invalid_target`, nothing rotated |
| `organization` | OPTIONAL; makes that organization the active one of the whole family (§17). Not one where the user has an active assignment → `400 invalid_grant`, nothing revoked or rotated |

Server behaviour (RFC9700 §4.14.2, `doc/decisions.md` D9):

- **Rotation on every use**: the response carries a new `refresh_token`; the
  presented one becomes used.
- **Reuse detection**: presenting an already-used refresh token revokes the
  **whole family** (every refresh token descended from the same grant) and
  answers `400 {"error":"invalid_grant"}`. The library treats any
  `invalid_grant` on refresh as a logout: it clears the stored session and
  emits `SignedOut(reason: sessionRevoked)`.
- A refresh token whose family, `sid` or user was revoked → `invalid_grant`.
- The library sends one refresh at a time per app (queued, one per API at
  most), so a legitimate client never presents a rotated token twice.
- Re-authentication: the server MAY answer `403` with the §5.5
  `insufficient_authorization` body (with `auth_session` and `next`) instead
  of tokens (FIPA §6.2, App. A.6). The library then asks the user and opens a
  new authorization on that `auth_session` (§5.2).
- Lifetimes: refresh tokens of public **web** clients expire 24 h after the
  original grant (absolute, not extended by rotation; BBA §6.3.2.3). The
  library assumes no lifetime: an expired token is an `invalid_grant` and a
  local sign-out; on the web the app then restores the session with a
  `prompt=none` redirect.
- If the response contains an `id_token`, it MUST have the same `iss`, `sub`
  and `aud` as before and SHOULD NOT contain `nonce` (OIDC-CORE §12.2).
- `device_secret`: issue a new one only when none or an invalid one was sent
  (OIDC-NSSO §3.4.3); a new `device_secret` requires a new `id_token` with the
  matching `ds_hash`.

### 7.3 `grant_type=urn:ietf:params:oauth:grant-type:token-exchange` (Native SSO)

OIDC-NSSO §4 over RFC8693:

| Parameter | Value |
|---|---|
| `client_id` | REQUIRED (the second app) |
| `audience` | REQUIRED, the issuer identifier |
| `subject_token` | the shared ID token |
| `subject_token_type` | `urn:ietf:params:oauth:token-type:id_token` (RFC8693 §3; the hyphenated form in OIDC-NSSO §4.2's example is not used) |
| `actor_token` | the shared `device_secret` |
| `actor_token_type` | `urn:openid:params:token-type:device-secret` |
| `scope` | REQUIRED, includes `openid` (and `offline_access`, `device_sso`) |

Checks, in order (OIDC-NSSO §4.3, `doc/decisions.md` D11); any failure →
`400 {"error":"invalid_grant"}`:

1. `device_secret` is valid (stored hashed) and not revoked;
2. `subject_token` signature verifies with the issuer key (it MAY be expired
   and its `aud` is the first app, OIDC-NSSO §6.3);
3. `ds_hash` in `subject_token` matches the `device_secret`;
4. the `sid` is active;
5. the requesting `client_id` and the token's `aud` belong to the same SSO
   group (same company; the group lists the client IDs allowed to share);
6. scopes that need explicit consent → `400 {"error":"interaction_required"}`
   (the library falls back to the normal sign-in with `login_hint`).

The new refresh token family hangs from the **same `sid`**; ending that `sid`
invalidates it (OIDC-NSSO §4.3). The response (§7.4) adds
`issued_token_type: urn:ietf:params:oauth:token-type:access_token` and MUST
include `refresh_token` and an `id_token` for the second app (`aud` = its
`client_id`, no `nonce`).

### 7.4 Success response (`200`)

```json
{
  "access_token": "…",
  "token_type": "Bearer",
  "expires_in": 900,
  "refresh_token": "…",
  "id_token": "…",
  "scope": "openid offline_access device_sso profile email",
  "device_secret": "…",
  "auth_session": "…",
  "issued_token_type": "urn:ietf:params:oauth:token-type:access_token"
}
```

- `token_type`: `Bearer` (case-insensitive). Any other value is refused by
  0.1.0 (see §13 on DPoP).
- `expires_in`: 900 (15 minutes) for user access tokens.
- `refresh_token`: REQUIRED for first-party clients (they are pre-authorized
  for `offline_access`, OIDC-CORE §11).
- `id_token`: REQUIRED for `authorization_code` and token exchange.
- `device_secret`: when `device_sso` was granted (OIDC-NSSO §3.4.2: the
  `device_secret` and the `id_token` are issued together or not at all).
- `auth_session`: MAY be returned after a challenge-endpoint code
  (FIPA §6.1); the library keeps it for step-up.

### 7.5 Errors

RFC6749 §5.2 with `400` (`invalid_request`, `invalid_grant`,
`unauthorized_client`, `unsupported_grant_type`, `invalid_scope`,
`interaction_required`) or `401` (`invalid_client`); `403` only for
`insufficient_authorization` (§7.2); `429` per §1.

## 8. Tokens

### 8.1 ID token

- Signed RS256 by default (OIDC-CORE §15.1), ES256 if the client registered
  `id_token_signed_response_alg=ES256`. Header: `alg`, `kid`; `typ` absent or
  `JWT` (never `at+jwt`, RFC8725 §3.11). No `crit`.
- Claims:

| Claim | Rule |
|---|---|
| `iss` | the issuer, exactly |
| `sub` | immutable, never reused `company_user` identifier; never the email |
| `aud` | the client's `client_id` (single value recommended; with several values `azp` MUST be the client) |
| `exp`, `iat` | lifetime 1 h |
| `auth_time` | always |
| `nonce` | REQUIRED and equal to the request's `nonce` when one was sent (OIDC-CORE §2) |
| `sid` | REQUIRED; the device session for native sign-ins, the browser session for browser sign-ins (OIDC-NSSO §3.4.1) |
| `amr` | RFC8176 values (`pwd`, `otp`, `mfa`, …) |
| `acr` | when requested |
| `company_id` | **LoginFlow claim**: the company of the identity (tenant) |
| `ds_hash` | REQUIRED when a `device_secret` is issued; HMAC of the secret under a server key (OIDC-NSSO §3.4.1) |
| `email`, `email_verified`, `name` | with `email` / `profile` scopes |
| `ext_sub`, `subject_kind`, `ext_profile` | **LoginFlow extension**, access-code subjects only (§16). The library reads `subject_kind` and `ext_profile` only when `ext_sub` is present, and never reads the standard `profile` claim |

The library validates every ID token before trusting it (OIDC-CORE §3.1.3.7):
signature with the JWKS key named by `kid`, `alg` ∈ {RS256, ES256} ∩
discovery, `iss`, `aud`, `azp`, `exp` and `iat` (60 s skew), `nonce`, and on
refresh/step-up that `sub` is unchanged.

### 8.2 Access token

RFC9068 JWT (`typ: at+jwt`, ES256). `aud` is the audience of ONE API of the
application (§17), or the issuer for the session's own token. It MUST carry
`sid` so §10 can identify the device session from it. The library verifies
nothing in it; it only decodes `org_id`, `org_ext`, `permissions` and
`permissions_overage` for the UI (§17), and treats any other token as
opaque.

## 9. Revocation: `POST {revocation_endpoint}`

RFC7009: `token`, `token_type_hint=refresh_token`, `client_id`. The server
checks the token was issued to that client (RFC7009 §2.1), revokes it and its
family and the access tokens of the same grant (§2), and answers `200` with an
empty body, also for unknown tokens (§2.2). A known token issued to a
**different** `client_id` answers `400 {"error":"unauthorized_client"}` and is
not revoked. Used by app-level logout; the library clears the local session
whatever this call returns (including that 400).

## 10. Device session logout: `POST {loginflow_device_logout_endpoint}`

**LoginFlow extension** (OIDC-NSSO defines no logout endpoint).

- `Authorization: Bearer <access_token>` (RFC6750 §2.1); body
  `client_id=<client>`.
- Ends the `sid` carried by the access token: revokes every refresh token
  family under it and every `device_secret` bound to it. Sibling apps get
  `invalid_grant` on their next refresh.
- `204` on success; `401 {"error":"invalid_token"}` for a bad token.
- On success the library deletes the shared SSO entry and the local session.

## 11. Global logout: `POST {loginflow_global_logout_endpoint}`

**LoginFlow extension** ("sign out everywhere", `doc/decisions.md` D14).

- Same authentication and body as §10.
- Ends every `sid` (native and browser) and revokes every refresh token of
  the user in the company. In federations the revocation runs in the home
  company.
- `204` on success.

## 12. RP-initiated logout: `GET {end_session_endpoint}`

OIDC-RPI §2: `client_id`, `id_token_hint`, `post_logout_redirect_uri`,
`state`. The server ends the browser session, revokes its refresh tokens and
redirects to `post_logout_redirect_uri?state=…` only when that URI exactly
matches a registered value (§3); otherwise it shows a confirmation page.
The library uses it for `SignOutScope.browser` (and on the web after
app-level logout when the app asks for it).

## 13. DPoP (RFC 9449)

**Mandatory for every `first_party` client that is registered `native` or
that registered browser origins (`allowed_web_origins`, §1.7 and §5.1).** The
library attaches a proof to the authorization challenge endpoint (§5), the
token endpoint (§7) and every resource request that carries an access token
(§10, §11): the device-logout and global-logout endpoints, `userinfo`, and
the REST scopes `/v1/user` (including the passkey account API of §15),
`/v1/app` (the members API of §18) and the panel's. Every one of those
resource endpoints runs the
same check (§13.3–§13.5): a DPoP-bound token only as `DPoP` with a matching
proof, a plain token only as `Bearer`.
`token_endpoint_auth_method=none` public clients outside that combination
(web, SPA without registered browser origins) are unaffected and keep sending
`Authorization: Bearer <token>`.

**Browser first-party apps (LoginFlow profile).** A first-party client with
`allowed_web_origins` signs in natively from those origins and MUST bind its
tokens: the token endpoint refuses its code, refresh and token-exchange
grants without a valid proof (`400 invalid_dpop_proof`) and issues
`token_type: "DPoP"` with `cnf.jkt` and a key-bound refresh family. The
browser keeps the non-extractable WebCrypto key of §13.1, so a persisted
refresh token is useless without it. The refresh family of a public web
client keeps its 24 h absolute lifetime.

### 13.1 The key

A non-exportable ES256 (P-256) key, one per app installation, generated and
held entirely outside Dart:

- iOS/macOS: the Secure Enclave (`SecureEnclave.P256.Signing.PrivateKey`),
  falling back to a Keychain-only key where there is none (the Simulator,
  Intel Macs without a T2 chip).
- Android: the Android Keystore, with `setIsStrongBoxBacked(true)` when the
  device has a StrongBox HSM, falling back to the regular Keystore
  (`StrongBoxUnavailableException`) otherwise. Still non-exportable either
  way.
- Flutter web: a non-extractable WebCrypto `CryptoKey`
  (`SubtleCrypto.generateKey(..., extractable: false, ...)`), persisted in
  IndexedDB (a non-extractable `CryptoKey` is structured-cloneable, so it
  survives the round trip and stays non-extractable) so the key — and the
  `jkt` the server bound the refresh token to — survives a page reload. If
  IndexedDB is unavailable or the stored key cannot be read back (private
  browsing, a cleared store), a fresh key is generated instead; the existing
  refresh token no longer matches its `jkt`, the next refresh fails with
  `invalid_grant`, and the library's already-documented behaviour for that
  (§7.2: clear the session, sign out) applies — an explicit new sign-in, not
  a silent one.

Only the public JWK and signatures the platform produces ever reach the
library; the private key material never crosses into Dart.

### 13.2 The proof

A JWS in compact serialization (RFC 9449 §4.2), sent as the `DPoP` request
header on every protected request:

- Header: `typ: "dpop+jwt"`, `alg: "ES256"`, `jwk` = the public key as an EC
  JWK (`kty`, `crv: "P-256"`, `x`, `y`; no `kid` needed, the embedded `jwk`
  **is** the key identifier, RFC 9449 §4.3 bullet 7).
- Payload: `htm` (the HTTP method), `htu` (the request URL **without query or
  fragment**, matching exactly what the server receives), `iat` (epoch
  seconds), `jti` (a fresh random value, single use), `nonce` (the last
  `DPoP-Nonce` the server sent, when any), and `ath` (`BASE64URL(SHA256(
  ASCII(access_token)))`) **only** on a resource request that also carries
  that access token — never on the token endpoint's own exchange of a code
  or refresh token for that token.
- Signature: raw `R || S` (64 bytes), ES256 (RFC 7518 §3.4), over the same
  signing input as any other JWS.

### 13.3 Access tokens and the `Authorization` header

With DPoP, a resource request sends `Authorization: DPoP <access_token>`
(RFC 9449 §7.1), never `Bearer`. The access token's `cnf.jkt` (RFC 7800)
MUST equal the JWK thumbprint (RFC 7638) of the key that signed the
accompanying proof; the server refuses a token presented with a proof from a
different key. `token_type` in the token response is `"DPoP"` instead of
`"Bearer"` for these clients.

### 13.4 Nonces

RFC 9449 §8: the server requires a server-provided nonce in every proof.
When a protected request is missing one, or presents a stale one, the server
answers with a `DPoP-Nonce` response header carrying the nonce to use: on
the token and authorization challenge endpoints as
`400 {"error":"use_dpop_nonce"}`, on a resource endpoint as `401` with
`WWW-Authenticate: DPoP error="use_dpop_nonce"` (RFC 9449 §9). **The library retries that same request exactly
once**, with a fresh proof carrying `nonce` set to the value from
`DPoP-Nonce`. A `DPoP-Nonce` header on a *successful* response is cached the
same way, pre-supplying the nonce for the next proof so steady-state traffic
does not need the extra round trip. A second `use_dpop_nonce` for the same
logical request is surfaced as `OAuthProtocolError(code: 'use_dpop_nonce')`,
not retried again.

### 13.5 Errors

- `400 {"error":"invalid_dpop_proof"}`: malformed proof, bad signature,
  `htm`/`htu` mismatch, expired `iat`, reused `jti`, or `ath` mismatch.
- `401` with a `WWW-Authenticate: DPoP error="invalid_dpop_proof"` header on
  a resource endpoint is treated the same as the `400` form above.
- Discovery publishes `dpop_signing_alg_values_supported: ["ES256"]` when
  DPoP is offered; the library does not currently gate on this field (every
  `first_party` client that is `native` or has browser origins is assumed to
  need DPoP per its registration, not per discovery), but a future version may.

### 13.6 Not part of 0.1.0

- **App attestation** (FIPA §9.1, ABCA): not implemented.
- **Back-channel logout** (OIDC-BCL): a server-to-backend feature; no client
  library involvement.

## 14. Server implementation checklist

1. Discovery fields of §2, at both well-known paths.
2. JWKS with one RSA and one EC key, `kid`, `alg`, `use`, cache headers (§3).
3. Client registry: `type`, `native`, `first_party`, `redirect_uris`,
   `post_logout_redirect_uris`, `allow_self_signup`, password reset switch,
   enabled login methods, Google web client ID, SSO group membership,
   `id_token_signed_response_alg`.
4. `GET` login options (§4).
5. Authorization challenge endpoint with the opening/continuation semantics,
   step parameters and responses of §5, anti-enumeration, per-session and
   per-account rate limits, OTP burn after 5 failures, Google nonce handshake
   and validation, internal PAR for `redirect_to_web`.
6. Authorization endpoint accepting `request_uri` and full requests, `iss` in
   every response, `prompt=none` errors (§6).
7. Token endpoint: code + PKCE with the `redirect_uri` rule, rotation with
   family revocation on reuse, `insufficient_authorization` on refresh,
   Native SSO token exchange with the checks of §7.3, `device_secret` +
   `ds_hash` issuance (§7).
8. ID token claims of §8.1, including `sid`, `company_id`, `ds_hash`;
   access tokens carrying `sid` (§8.2).
9. Revocation (§9), device logout (§10), global logout (§11),
   end-session (§12).
10. `Cache-Control: no-store`, 429 + `Retry-After`, RFC6749 error bodies (§1).
11. Passkeys challenge steps of §5.7 and the account API of §15.

## 15. Passkey account API (LoginFlow extension, authenticated)

Unlike every endpoint above, this is **not** part of
`GET /.well-known/openid-configuration`: it is a fixed account-management
REST surface under `/v1/user/passkeys`, resolved from `issuer` the same way
the server itself mounts it, never negotiated through discovery. Bodies are
`application/json` (not form-urlencoded — this is not an OAuth/OIDC
endpoint), authenticated with the user's access token
(`Authorization: Bearer` or `DPoP`, §13 applies the same way it does to
every other resource endpoint).

Every response, success or error, uses this server's general `ApiResponse`
envelope (`response_entity.rs`): success wraps the payload in
`{"data": <payload>, "meta": {"status", "timestamp", "request_id", "path"}}`;
error wraps it in `{"error": {"code", "message", "details"?}, "meta": {...}}`
(not the RFC 6749 §5.2 shape of §1.5 — this is account-management REST, not
an OAuth/OIDC endpoint). The "Response" column below is the `data` of that
envelope, not the raw body — `PasskeyAccountClient`
(`lib/src/core/http/login_flow_envelope.dart`) unwraps it on every call.

| Route | Body | Response (the envelope's `data`) |
|---|---|---|
| `POST /v1/user/passkeys/enroll/start` | `{"username", "display_name"}` | `200` `webauthn-rs`'s `CreationChallengeResponse`, unmodified — pass to `PasskeyAuthenticator.createCredential` |
| `POST /v1/user/passkeys/enroll/finish` | `{"credential", "name"?}` | `201` the stored credential (`id`, `name`, `created_at`, `last_used_at`) |
| `GET /v1/user/passkeys` | — | `200` an array of stored credentials |
| `PATCH /v1/user/passkeys/{id}` | `{"name"}` | `200` the updated credential |
| `DELETE /v1/user/passkeys/{id}` | — | `200` |

`enroll/start` and `enroll/finish` require a recently authenticated access
token (RFC 9470, `auth_time` within 300 s — the same gate as a password
change): a stale token answers `401` with
`WWW-Authenticate: Bearer error="insufficient_user_authentication",
max_age=300` before anything else runs. Never the public key, the AAGUID or
the transports — only what the user needs to recognize and manage their own
passkeys. `enroll/finish` verifies `clientDataJSON.origin` against the
company's RP origin and, when the request carries an `Origin` header that
is in the `allowed_web_origins` of the active first-party client the access
token was issued to (`client_id` claim), against that origin too (§5.7
related origins, LoginFlow profile): a first-party web app enrolls from its
own origin. Any other origin is still held to the RP origin; a request
without `Origin` (a native app) is unchanged.

## 16. Access codes (LoginFlow extension)

A tenant backend (a driver app's server, a school system, a kiosk fleet)
issues a single-use code for a subject that lives in **its own** database;
the person or device types it in the app and gets a LoginFlow session.
LoginFlow keeps no personal data for these subjects, only a minimal subject
record whose id is the token `sub`. Issuing, listing and revoking codes are
machine routes of the tenant backend (`/v1/service/access-codes`, scope
`loginflow.accessCodes.issue`), not part of this library.

**The code.** Exactly 8 characters from `23456789ABCDEFGHJKMNPQRSTUVWXYZ`
(no `0 O 1 I L`), generated with a CSPRNG, shown as `XXXX-XXXX`. Input is
case-insensitive and spaces and dashes are ignored; the library sends the
normalized value (`AccessCodeFormat.normalize`) and refuses locally anything
that is not 8 alphabet characters. The server stores only a keyed hash
(HMAC-SHA256 under a server pepper), never the code.

**Redemption.** Opening request of `POST {authorization_challenge_endpoint}`
(§5.2/§5.3 authorization parameters as usual) with `method=access_code` and
`access_code=<code>`, from a `first_party` client of the **same**
application, with a DPoP proof (§13) — REQUIRED here, not only at the token
endpoint: the session is bound to the device key. The claim is atomic and
the code is deleted on redeem, so it works once.

| Outcome | Response | Library |
|---|---|---|
| Valid code | `200 {"authorization_code"}`, then §7.1 as usual (DPoP-bound tokens) | `SignedIn` |
| Unknown, expired, used or revoked code | `400 {"error":"invalid_grant","error_description":"the access code is invalid, expired or already used"}` — the same body for every case (no enumeration) | `InvalidAccessCode` |
| Too many failures (per address/DPoP key, or the per-application threshold) | `429 {"error":"slow_down","error_description":"too many failed attempts"}` + `Retry-After: <seconds>` (e.g. `900`) | `AccessCodeThrottled(retryAfter)` |
| Access codes disabled for the application | `400 {"error":"access_codes_disabled","error_description":"access codes are disabled for this application"}` | `AccessCodesUnavailable` |
| `invalid_dpop_proof`, `unauthorized_client`, `invalid_scope`, `invalid_request`, `temporarily_unavailable` | RFC 6749 `{error, error_description}` | `OAuthProtocolError` with that `code` |
| A server without the method (answers a step or `redirect_to_web`) | — | `AccessCodesUnavailable` (the attempt is abandoned, no `ChallengeRequired`) |
| No `authorization_challenge_endpoint` in discovery | — (no request) | `UnsupportedByServer(feature: 'authorization_challenge_endpoint')` |

The challenge endpoint is not enveloped: error bodies are plain RFC 6749
`{error, error_description}`.

**Tokens.** `sub` is the subject id; the ID token and the access token carry
`ext_sub` (the tenant's own id, `<=128` chars of `[A-Za-z0-9:._-]`),
`subject_kind` (`person` or `device`) and `ext_profile` (the issuer-defined
`profile` given at issue, `<=40` chars, e.g. `Driver`, `Kiosk`; not the
standard OIDC `profile` claim, which is a profile-page URL). No `email`; `name` only when the
issuer gave a display name. Refresh rotation (§7.2) is unchanged; revoking
the subject on the server ends its sessions, and the next refresh fails with
`invalid_grant` (`SessionRevoked`).

## 17. Organizations and per-API access tokens (LoginFlow extension)

An application can have several independent APIs. Each one is a resource
(RFC8707) with its own audience; its permissions are its own. The user has
one session and one refresh family per application; every access token is
for ONE API and carries only that API's permissions in the **active
organization** — the product's unit of scope (a client company, a school).
Every application has one `root` organization; the product creates the
`regular` ones.

**Which token a request gets.**

| Request | `aud` of the access token | `permissions` |
|---|---|---|
| `resource=<api>`, an API linked to the client | `<api>` | that API's, in the active organization |
| `resource=<api>`, an API not linked to the client | — `400 {"error":"invalid_target"}` | — |
| `resource=<issuer>` (any sign-in client, §18) | the issuer (LoginFlow's own token, for the members API) | absent |
| no `resource`, the client has exactly one API | that API | that API's |
| no `resource`, the client has zero or several APIs | the issuer (the session's own token: userinfo, organizations, passkeys, logout) | absent |

**Active organization.** A request names one with `organization` (opening
of §5.3 / §6, or the refresh of §7.2) and gets it if the user holds an
active assignment there, `invalid_grant` otherwise. Without one, the family keeps
its organization; a new family gets the user's only organization, or none
when there are zero or several. With none, `org_id` is absent and
`permissions` is `[]`.

**Access-token claims** (beyond §8.2):

| Claim | Meaning |
|---|---|
| `app` | the application id (`aud` is no longer the application) |
| `org_id` | the active organization id; absent when none |
| `org_ext` | the product's own id of the active organization; absent for `root` |
| `permissions` | array of `app.resource.action` keys; absent on the session's own token and on overage |
| `permissions_overage` | `true` when the permissions exceed 150 entries or 4096 bytes; the API resolves them through introspection |

**`GET {organizations_endpoint}`** with the session's access token
(`Authorization: Bearer` or `DPoP` + proof, §13), plain JSON, no envelope:

```json
{
  "active": "5f0c…",
  "organizations": [
    {"id": "5f0c…", "external_id": "client-42", "name": "Transportes Norte", "kind": "regular"},
    {"id": "9a1b…", "external_id": null, "name": "RutaFácil", "kind": "root"}
  ]
}
```

`active` is `null` when no organization is active. Errors as any resource
(`401` + `WWW-Authenticate`).

**Library behaviour.**

| Call | Wire | Result |
|---|---|---|
| any sign-in method with `organization:` | `organization` on the opening request (§5.3) or the authorization URL (§6) | the session starts in it |
| `accessTokenFor(api)` | refresh with `resource=<api>`, same DPoP key; cached per API until 30 s before `expires_in` | the token; `InvalidTarget(api)` on `invalid_target` (session kept); `ConfigurationInvalid` for an API missing from `LoginFlowConfig.apis` (no request) |
| `authorizedHeadersFor(api, method:, uri:)` | — | `Authorization` + `DPoP` for that API's token (§13.3) |
| `listOrganizations()` | `GET {organizations_endpoint}` | `OrganizationList`; `UnsupportedByServer('organizations_endpoint')` without it in discovery |
| `switchOrganization(id)` | refresh with `organization=<id>`, no `resource` | every cached API token dropped, `accessClaims` emptied; `OrganizationUnavailable(id)` on `invalid_grant` (session kept) |
| `session.accessClaims[api]` | the four claims above, decoded **without verification** | for the UI only; the API decides access |

## 18. Members API (LoginFlow extension, authenticated)

A person of a product manages who holds which role in the organizations
their own roles reach — the generic "Team" screen of any product. The server
decides every grant and revocation with its delegation rules: a role is
granted only if one of the person's live assignments lists it as grantable,
in an organization that assignment reaches (the same one, or from the root
into the company's regular organizations), only with permissions and an
expiry the person holds there, and never to or from the person's own
account. There is no route here that edits roles, catalogs or grantable
lists: that is the application owner's, on the LoginFlow panel.

**Token.** The person's OWN LoginFlow token: `aud` = the issuer, asked with
`resource=<issuer>` on the session's refresh (§7.2), which is valid for every
sign-in client whatever its APIs (§17). Presented as `Authorization: DPoP
<token>` with its proof (§13): a plain bearer token is `401` +
`WWW-Authenticate: DPoP error="invalid_token"`; a product API's token is `403
wrong_audience` (a product backend that received it can never replay it here);
an access-code subject's token is `403 permission_denied`. Every write needs a
recent strong sign-in: `401` + `WWW-Authenticate: Bearer
error="insufficient_user_authentication", max_age=300` otherwise (RFC 9470).

Fixed account-API paths under the issuer, with the `ApiResponse` envelope
(`{"data", "meta"}` / `{"error": {"code", "message", "details"?}, "meta"}`),
like §15. Instants in answers are UTC without an offset
(`2026-12-31T00:00:00`); `expires_at` in a request is RFC 3339 with its
offset. Bodies and queries reject unknown fields (`400`).

| Route | Body / query | Answer |
|---|---|---|
| `GET /v1/app/members/grantable-roles` | `?organization_id` | `200 {organization: {id, name, kind}, roles: [{id, key, name, description, max_expires_at}]}`; empty `roles` = no grant power there |
| `GET /v1/app/members` | `?organization_id&q&limit(1..100, default 50)&offset` | `200 {items: [{principal_id, email, name, assignments: [{id, role: {id, key, name}, expires_at, manageable}]}], total}` |
| `POST /v1/app/members/invitations` | `{organization_id, email, first_name?, last_name?, role_id, expires_at?}` | `201` (`200` when the same assignment existed) `{member: {principal_id, email, name}, assignment, invitation: sent \| not_needed \| rate_limited \| failed}` |
| `POST /v1/app/members/{principal_id}/assignments` | `{organization_id, role_id, expires_at?}` | `201` (`200` when it existed) `{id, role, expires_at, manageable}` |
| `DELETE /v1/app/members/assignments/{assignment_id}` | — | `204` |

**Refusals** (`error.code`): `404` `organization_not_found`,
`role_not_found`, `member_not_found`, `assignment_not_found`; `403`
`organization_out_of_reach`, `role_not_grantable`,
`privilege_exceeds_grantor` (`details.dimension`: `permissions` /
`expiry`), `self_assignment_forbidden`, `wrong_audience`,
`permission_denied`; `409` `member_inactive`, `system_application`; `422`
`role_not_assignable_here`, `expires_at_in_past`.

**Library behaviour.**

| Call | Wire | Result |
|---|---|---|
| `listGrantableRoles(organizationId:)` | `GET …/grantable-roles` | `GrantableRoles` (`canGrant` false: hide the screen) |
| `listMembers(organizationId:, query:, limit:, offset:)` | `GET /v1/app/members` | `MembersPage` of `OrganizationMember` |
| `inviteMember(organizationId:, email:, roleId:, …)` | `POST …/invitations` | `MemberInvitation` (`InvitationStatus`) |
| `grantRole(organizationId:, principalId:, roleId:, expiresAt:)` | `POST …/{principal_id}/assignments` | `MemberAssignment` |
| `revokeAssignment(assignmentId)` | `DELETE …/assignments/{id}` | `void`; offer it only when `MemberAssignment.manageable` |

Every call uses LoginFlow's own token, asked once with `resource=<issuer>`
(same refresh family and DPoP key) and cached until 30 s before it expires,
apart from the API tokens (it never appears in `session.accessClaims`). A
refusal is `DelegationDenied(code, statusCode)` with a
`DelegationDenialCode`; a write past the recent-sign-in window is
`StepUpRequired` (call `stepUp`, then the call again); `429` is
`RateLimited`.

## 19. Email change (LoginFlow extension, authenticated)

A person changes their OWN email, from any product. Same door as §18: the
person's own DPoP-bound LoginFlow token (`aud` = the issuer); a product API's
token is `403 wrong_audience`, a machine or access-code token `403
permission_denied`. Who changes their email is the token's `sub`, never the
body (bodies reject unknown fields, `400`). The machine door's former
`/v1/service/users/{id}/email-change*` is gone (`404`).

| Route | Body | Answer |
|---|---|---|
| `POST /v1/app/email-change` | `{new_email}` | `202 {expires_at, confirm_current}` |
| `POST /v1/app/email-change/confirm` | `{code, current_code?}` | `200 {email, email_verified: true}` |

**Step-up, decided from the credential on every start.** With a second
factor (TOTP or a passkey): a recent STRONG sign-in, else `401` +
`WWW-Authenticate: Bearer error="insufficient_user_authentication",
acr_values="urn:loginflow:acr:phr urn:loginflow:acr:mfa", max_age=300`.
Without one: a recent sign-in, else the same challenge without `acr_values`.
The confirmation needs no step-up.

**Codes.** 6 digits, 15 min, 5 attempts each; a new start replaces the open
request. One code to the new address; without a second factor another one
to the current address (`confirm_current: true`) and the confirmation needs
both. When another identity holds the new address the start answers the
same `202` but sends no code there.

**Errors.** Start: `422 VALIDATION_ERROR` (malformed, disposable, or the
current email — `details` says which), `429 RATE_LIMITED` + `Retry-After`
(3 starts per hour). Confirm: `422 VALIDATION_ERROR` (a code that is not 6
digits), `401 INVALID_CODE` for every refusal (wrong, expired, burned or used
code, a missing `current_code`, an address taken since the start).

**After a confirmation** every OTHER session of the person ends; this one
continues, and its next refresh carries an ID token with the new `email`
(`email_verified: true`).

**Library behaviour.**

| Call | Wire | Result |
|---|---|---|
| `startEmailChange(newEmail)` | `POST /v1/app/email-change` | `EmailChangeStarted(expiresAt, confirmCurrent)` |
| `confirmEmailChange(code, currentCode:)` | `POST …/confirm` | `EmailChangeConfirmed(email, isEmailVerified)`, then a refresh of the session (a new `SignedIn`) |

The start's challenge is `StepUpRequired`; `StepUpRequirement.isStrongRequired`
tells the strong one (`acr_values`) from the recent one (`max_age` alone).
Call `stepUp`, then start again: the step-up's tokens replace the cached
LoginFlow token, so the retry presents the new sign-in. `422` on the start is
`InvalidEmailAddress`; `422` and `401 INVALID_CODE` on the confirmation are
`InvalidEmailChangeCode`; `429` is `RateLimited`.
