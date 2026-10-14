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
7. CORS: allowed on discovery, JWKS, token, revocation and the login options
   endpoint; never on `/oauth2/authorize` (RFC9700 §2.6).

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
  "login_methods": ["password", "email_otp", "google", "microsoft"],
  "self_signup": true,
  "password_reset": true
}
```

- `client_id` MUST echo the request (the library rejects a mismatch).
- `login_methods` wire names: `password`, `email_otp`, `google`,
  `microsoft`. Unknown future names are ignored by older libraries. TOTP is
  not a primary method; it appears as a challenge step (§5).
- `self_signup`: the application's `allow_self_signup` flag.
- `password_reset`: whether the hosted reset flow is enabled for the client.
- Unknown `client_id`: `404 {"error":"invalid_client"}`.

## 5. Authorization Challenge Endpoint: `POST {authorization_challenge_endpoint}`

FIPA §4–§7 with the **LoginFlow profile** below.

### 5.1 Who may call it

Only clients registered `public` + `native` + `first_party = true`
(FIPA §1.1, §9.1). Others: `400 {"error":"unauthorized_client"}`. Public
clients identify themselves with `client_id`; no client secret is accepted
(RFC8252 §8.4–8.5).

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
| `upstream_provider` | `google` or `microsoft` |
| `upstream_flow` | `native` (Google only: the app will post a Google ID token) or `browser` (answered with `redirect_to_web`) |
| `upstream_token` | The Google ID token (with `upstream_provider=google`) |
| `intent` | `password_reset` → `redirect_to_web` to the hosted reset flow (FIPA App. A.2); MAY carry `login_hint` |

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
wire names of §4 (`password`, `email_otp`, `google`, `microsoft`). The client
continues with `method=password` / `method=email_otp`, or opens
`upstream_provider=google|microsoft`. The status is 403, not 200: FIPA §5.2.2
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
  the server, bound to the `auth_session`, single use. `client_id` is the
  company's Google **web** client ID; the app passes it to the Google SDK as
  `serverClientId`.

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

Used for Microsoft (always), Google with `upstream_flow=browser`,
`prompt=create`, `intent=password_reset`, and any risk-based decision
(FIPA §9.2). `request_uri` references an internal pushed authorization
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

## 6. Authorization endpoint (browser): `GET {authorization_endpoint}`

Used by `redirect_to_web` and by Flutter web (top-level redirect).

Pushed form (RFC9126 §4): `?client_id=…&request_uri=…`.

Full form (RFC6749 §4.1.1, RFC7636 §4.3, OIDC-CORE §3.1.2.1):
`response_type=code`, `client_id`, `redirect_uri`, `scope`, `state`, `nonce`,
`code_challenge`, `code_challenge_method=S256`, optional `prompt`
(`none` | `login` | `create` | `select_account`) and `login_hint`.

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

Server behaviour (RFC9700 §4.14.2, `doc/decisions.md` D9):

- **Rotation on every use**: the response carries a new `refresh_token`; the
  presented one becomes used.
- **Reuse detection**: presenting an already-used refresh token revokes the
  **whole family** (every refresh token descended from the same grant) and
  answers `400 {"error":"invalid_grant"}`. The library treats any
  `invalid_grant` on refresh as a logout: it clears the stored session and
  emits `SignedOut(reason: sessionRevoked)`.
- A refresh token whose family, `sid` or user was revoked → `invalid_grant`.
- The library sends one refresh at a time per app (single-flight), so a
  legitimate client never presents a rotated token twice.
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

The library validates every ID token before trusting it (OIDC-CORE §3.1.3.7):
signature with the JWKS key named by `kid`, `alg` ∈ {RS256, ES256} ∩
discovery, `iss`, `aud`, `azp`, `exp` and `iat` (60 s skew), `nonce`, and on
refresh/step-up that `sub` is unchanged.

### 8.2 Access token

Opaque to the library. RFC9068 JWT (`typ: at+jwt`, ES256, `aud` = the
application) is the server's choice for resource servers. It MUST carry `sid`
so §10 can identify the device session from it.

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

## 13. Not part of 0.1.0

- **DPoP** (RFC9449). the LoginFlow profile makes a DPoP proof required for
  native clients in the LoginFlow profile. Library 0.1.0 does not send DPoP
  proofs (it needs a non-exportable Secure Enclave / StrongBox key per app,
  scheduled for the next version). Until then the server MUST NOT require
  DPoP for first-party native clients and MUST issue `token_type: Bearer`.
- **App attestation** (FIPA §9.1, ABCA): phase 2.
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
