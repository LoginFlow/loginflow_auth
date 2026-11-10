# Changelog

## 0.21.0

Shares `major.minor` with LoginFlow API `0.21.x`.

- New: `ClientLoginOptions.passkeyRpId` — the `passkey_rp_id` LoginFlow
  publishes in `GET /oauth2/login-options` (the company's passkey host,
  whenever its passkey policy is not disabled).
- Changed (breaking): `LoginFlowAuth.parseSignInQr(scanned)` is now
  `Future<Result<SignInQr, LoginFlowError>>`. Without
  `LoginFlowConfig.passkeyRpId` it reads the client's login options and
  checks the QR against the published host; `.notConfigured` only when
  neither names one, and a failed read is returned as is. A configured
  `passkeyRpId` keeps priority and makes no request, as before.
- New: `LoginFlowConfig.isPlainHost(value)`, the host check
  `passkeyRpId` already used.
- Fixed: `passkeys` is required at `^2.24.1` — the authenticator already
  matched exceptions that only exist from 2.24, so a project resolving
  2.23.x did not compile.

## 0.20.0

Both sides of LoginFlow's two sign-ins on another device: approval on a
phone (`device_push`, number matching) and QR (`device_qr`). Server
contract: `doc/server-contract.md` §21.

**Versioning.** From this release the library shares its `major.minor`
with the LoginFlow API and the web library: API `0.20.x` ↔ `loginflow_auth`
`0.20.x` ↔ `loginflow_auth_web` `0.20.x`. Patch numbers move on their own;
versions stay `0.x.y`.

Requester (this app signs in, approved on another device), same concepts
and names as `loginflow_auth_web`:

- New: `LoginFlowAuth.requestPhoneApproval(email, {organization})` →
  `Result<AuthState, LoginFlowError>` (`method=device_push`). Resolves once
  the request exists: `ChallengeRequired` on `ChallengeStep.devicePush`
  whose `prompt.phoneApproval` (`PhoneApproval`: `number`, `expiresAt`)
  says what to show.
- New: `LoginFlowAuth.requestQrSignIn({organization})` (`method=device_qr`,
  no email): `ChallengeStep.deviceQr` with `prompt.qrSignIn` (`QrSignIn`:
  `qrUri`, `expiresAt`).
- Both are then polled by the library (`method=device_push_poll` /
  `device_qr_poll`) at LoginFlow's `interval`, 5 s more after every
  `slow_down` (RFC 8628), through network failures until the request
  expires. Approved: `SignedIn`, the session stored as with any other
  method. Refused or expired: the same step with `prompt.stepError`
  `StepError.denied` / `StepError.expired` and no number or QR; ask again
  for a new one. Waiting polls emit no state. `cancelChallenge`, another
  sign-in, `selectMethod`, `signOut` and `dispose` stop the polling.
  `selectMethod(ChallengeStep.devicePush | deviceQr)` asks on the attempt in
  progress.
- New: `LoginFlowAuth.deviceSignInWait` (`Duration`), the time left on the
  phone approval or QR on screen, on the library's clock.
- New: `LoginFlowScheduler` / `TimerLoginFlowScheduler`, the
  `LoginFlowAuth(scheduler:)` that paces the polling (tests replace it).
- New: `ChallengeStep.devicePush`, `ChallengeStep.deviceQr`,
  `StepError.denied`, `StepError.expired`, `DeviceSignInDetails`,
  `DevicePollStatus`; `ChallengeStepRequired.device` / `.pollStatus`;
  `ChallengePrompt.phoneApproval` / `.qrSignIn`.

Approver, QR (this app, signed in, approves a page's QR):

- New: `LoginFlowConfig.passkeyRpId` — the company's passkey host (the one
  the app's `webcredentials:` / `assetlinks.json` already name, e.g.
  `acme-id.loginflow.dev`). The library has no other source for it: the
  server publishes it nowhere an app can read before a passkey ceremony.
- New: `LoginFlowAuth.parseSignInQr(scanned)` →
  `Result<SignInQr, LoginFlowError>`: accepts only
  `https://<passkeyRpId>/qr/<uuid>#<secret>`, no request. Otherwise
  `InvalidSignInQr(problem)`: `SignInQrProblem.otherCompany` (another
  host, never sent), `.malformed`, `.notConfigured` (no `passkeyRpId`).
  The library has no camera dependency: the app scans and passes the text.
- New: `LoginFlowAuth.signInQrDetails(qr)` → `SignInQrDetails`
  (`POST /v1/user/device-qr/{id}/details`), `approveQrSignIn(qr)` (passkey
  step-up first or after the RFC 9470 challenge, then one retry — the same
  helper as `approvePhoneSignIn`), `denyQrSignIn(qr)`. The secret only
  travels in the JSON body.
- New: `SignInQrRefused(reason)` with `SignInQrRefusal.notFound`,
  `.expired`, `.notAllowed` (`device_qr_not_found`, `_expired`,
  `_not_allowed`); `429` stays `RateLimited`.

Built-in sign-in UI:

- New methods `PhoneApprovalMethod` (`device_push`) and `QrSignInMethod`
  (`device_qr`) for `SignInConfiguration.methods`, shown only when the
  client's login options list them. "Approve on my phone" asks for the
  email, then shows the number large with "Expires in m:ss"; "Sign in with a
  QR code" renders the QR with its countdown. Refused or expired: the reason
  and "Send a new request" / "Show a new code". English and Spanish texts.
- New dependency: `qr` ^4.0.0 (pure Dart, BSD-3, no transitive dependency
  but `meta`) to encode the QR; drawn by the library's own `CustomPainter`
  (black on white with the 4-module quiet zone, whatever the theme).

Breaking (exhaustive switches): new cases in `ChallengeStep`, `StepError`,
`AuthMethod`, and two new `LoginFlowError` subclasses (`SignInQrRefused`,
`InvalidSignInQr`); a `switch` over them without a catch-all must add them.

## 0.19.0

Approver side of LoginFlow's sign-in by phone approval (`device_push`,
number matching): a first-party web page asks to sign in as a person and
shows a two-digit number; the person, signed in to the app, picks the same
number among three and confirms with a passkey. Server contract:
`doc/server-contract.md` §21 (new; documents `device_qr` and `device_push`,
requester steps and approver routes).

- New: `LoginFlowAuth.pendingPhoneApprovals()` →
  `Result<List<PhoneApprovalRequest>, LoginFlowError>`
  (`GET /v1/user/device-push/pending`). `PhoneApprovalRequest` (`requestId`,
  `clientId`, `clientName`, `applicationId`, `requester`, `choices`,
  `createdAt`, `expiresAt` in UTC) and `PhoneApprovalRequester` (`device`,
  `ipAddress`), with `copyWith`, `==`, `hashCode`, `fromJson`/`toJson`.
- New: `LoginFlowAuth.approvePhoneSignIn({requestId, number})` →
  `Result<PhoneApprovalOutcome, LoginFlowError>`
  (`POST /v1/user/device-push/{id}/approve`): `PhoneApprovalOutcome.approved`
  or `.wrongNumber` (denied for good, one try). The server needs a passkey
  within the last 120 s; the call runs the passkey step-up itself
  (`LoginFlowAuth.phoneApprovalRequirement`: `acr_values`
  `urn:loginflow:acr:phr`, `max_age` 120 s) before sending when the session's
  last sign-in is not a recent passkey, or on the server's RFC 9470
  challenge, then sends the approval exactly once more.
- New: `LoginFlowAuth.denyPhoneSignIn(requestId)` → `Result<void, LoginFlowError>`
  (`POST /v1/user/device-push/{id}/deny`), no step-up.
- New: `PhoneApprovalRefused(reason)` with `PhoneApprovalRefusal.notFound`,
  `.expired` and `.notAllowed` (`device_push_not_found`, `_expired`,
  `_not_allowed`); `429` stays `RateLimited`.
- New: `LoginFlowAuth.phishingResistantAcr` (`urn:loginflow:acr:phr`).
- Breaking (exhaustive switches): `LoginFlowError` has a new subclass,
  `PhoneApprovalRefused`; a `switch` over `LoginFlowError` without a
  catch-all must add it.
- No bundled approval screen in this release: the app renders the request
  (client name, device, address, the three numbers, deny) itself.

## 0.18.0

Email-code resend cooldown owned by the library. LoginFlow answers an
email-code request the same whether or not an email left, and sends no new
code for a while once one was issued; a "Resend code" pressed at once did
nothing visible and people got stuck.

- New: `LoginFlowConfig.emailCodeResendCooldown` (`Duration`, default
  `LoginFlowConfig.defaultEmailCodeResendCooldown` = 60 s). `validate()`
  refuses a value that is not positive; its JSON form is
  `email_code_resend_cooldown_seconds` (absent → 60).
- New: `ChallengePrompt.resendAvailableAt` (`DateTime?`, UTC; JSON
  `resend_available_at`): set on the `email_otp` step one cooldown after the
  code is requested and after each accepted resend; a wrong or expired code
  keeps it; `cancelChallenge` or a new attempt clears it; `null` on any
  other step.
- New: `LoginFlowAuth.emailOtpResendWait` (`Duration`): the wait left on the
  library's clock, `Duration.zero` when a resend is allowed or no
  email-code step is in progress.
- Changed: `resendEmailOtp()` before `resendAvailableAt` fails with
  `RateLimited(retryAfter: <wait left>)` and sends no request.
- Breaking: `EmailOtpMethod.resendCooldown` (and its JSON
  `resend_cooldown_seconds`) is removed: the wait is the core's, not the
  UI's. Migration: `EmailOtpMethod(resendCooldown: d)` →
  `EmailOtpMethod()` plus `LoginFlowConfig(emailCodeResendCooldown: d)`.
- Sign-in UI: the email-code step shows "Resend code (0:42)" disabled until
  the wait is over, read from the library's clock every second (the
  `SignInViewModel` timer, never `build()`), and the help line "It can take
  up to 2 minutes; check spam. The code lasts 30 minutes." (es: "Puede
  tardar hasta 2 minutos; revisa también spam. El código sirve 30
  minutos."). The password reset's code step counts the same configured
  cooldown. New `LoginFlowStrings.resendCodeCountdown(time)` and
  `LoginFlowStrings.emailCodeHelp` — a custom `LoginFlowStrings`
  implementation must add them.
- Fixed: builds against `passkeys` 2.24, whose new
  `ConditionalCreateNotEligibleException`,
  `ConditionalCreateUnsupportedException` and
  `PasswordCredentialUnsupportedException` broke the exhaustive switch in
  `CorbadoPasskeyAuthenticator`; they map to
  `PasskeyFailureReason.notSupported`.

## 0.17.0

In-app password reset owned by the library: every authentication of a
first-party app now happens in the app. "Forgot your password?" is an
emailed code, the new password, then signed in — no browser, no
`redirectUri`. Built on the server's email-code sign-in (the authorization
challenge's `email_otp`) and `POST /v1/user/change-password`, with the
library's step-up when the account needs a strong sign-in.

- Breaking: `LoginFlowAuth.resetPassword({loginHint, organization})` is
  removed, and with it `intent=password_reset` and the browser hand-off it
  opened. Migration:

  | Before (0.16.x) | Now (0.17.0) |
  |---|---|
  | `auth.resetPassword(loginHint: email)` → browser → `SignedIn` | `auth.startPasswordReset(email)` → `AwaitingResetCode` |
  | (the hosted page asked for the code) | `auth.submitResetCode(code)` → `AwaitingNewPassword` (or a `ChallengeRequired(purpose: passwordReset)` for TOTP first) |
  | (the hosted page asked for the password) | `auth.setNewPassword(password)` → `SignedIn` (or the step-up's `ChallengeRequired`; the password is resent by itself after it) |
  | close the browser | `auth.cancelPasswordReset()` → `SignedOut` from any step |
  | — | `auth.resendResetCode()` |

  The client's login methods must include `email_otp`; `redirectUri` is no
  longer needed for the reset.
- New: `startPasswordReset(email, {organization})`, `submitResetCode(code)`,
  `resendResetCode()`, `setNewPassword(newPassword)` and
  `cancelPasswordReset()` on `LoginFlowAuth`, all
  `Future<Result<AuthState, LoginFlowError>>`. The session the code opens is
  held — never stored, never a `SignedIn`, not shared through Native SSO,
  no `accessTokenFor` — until the new password is set; cancelling signs it
  out of this app (refresh token revoked).
- Breaking: `AuthState` gains `AwaitingResetCode(email)` and
  `AwaitingNewPassword(email)`; an exhaustive `switch` over `AuthState`
  needs their cases.
- Breaking: `ChallengePurpose` gains `passwordReset`: a second factor or
  step-up asked within a reset.
- Breaking: `LoginFlowError` gains `InvalidResetCode` (wrong code, or any
  code for an address with no account), `ResetCodeExpired` (expired or
  burned) and `AlreadySignedIn` (a reset started with someone signed in);
  an exhaustive `switch` over `LoginFlowError` needs their cases.
  `PasswordRejected(reason)`, `RateLimited` and `NetworkFailure` keep the
  reset on its current step.
- Breaking: `LoginFlowStrings` gains `resetPasswordTitle`,
  `resetCodeSentTo(email)`, `newPasswordTitle`, `newPasswordLabel`,
  `repeatPasswordLabel`, `savePasswordButton`, `passwordMismatch` and
  `feedbackPasswordRejected`; a custom implementation needs them.
- Changed: the bundled UI's "Forgot your password?" runs the in-app reset
  (a code step with resend, then the new password typed twice). It shows
  only when the server enables reset **and** the client allows `email_otp`.
  On the reset's step-up the password step hides "Forgot your password?"
  and its passkey button answers the step-up.
- Docs: README "Password reset (in-app)", `doc/integration-guide.md`
  section 4.2, `doc/decisions.md` D4, `doc/server-contract.md`.
- Tests: `test/core/password_reset_test.dart` (the flow against the fake
  server: happy path, wrong/expired code, resend, rate limit, TOTP, passkey
  step-up, refused password, refresh while held, cancel at each step, the
  browser reset gone), `test/sign_in/sign_in_viewmodel_password_reset_test.dart`,
  a widget test, and the `reset_code` and `new_password` goldens. The fake
  server can answer `step_error=code_expired` (`isEmailOtpExpired`).

## 0.16.0

In-app password change: the signed-in person sets or changes their own
password through LoginFlow's `POST /v1/user/change-password`, with the
session's own token like the passkey and TOTP calls — no browser.

- New: `LoginFlowAuth.changePassword(newPassword)` →
  `Result<void, LoginFlowError>`. It needs a recent sign-in (strong when the
  account has TOTP or a passkey): `StepUpRequired`, then `stepUp` and ask
  again. `NotSignedIn` without a session.
- Breaking: `LoginFlowError` gains `PasswordRejected(reason)` (`422
  VALIDATION_ERROR`: a weak, breached or unchanged password; `reason` is the
  server's `error.details`); an exhaustive `switch` over `LoginFlowError`
  needs its case.
- Tests: the fake server answers the route like
  `auth_handler.rs::change_password` (DPoP, the recent-auth gate, `422`).

## 0.15.0

Authenticator app management (`doc/server-contract.md` §20): the signed-in
person turns TOTP on and off and gets recovery codes, through LoginFlow's
`/v1/user/totp/*`, with the session's own token like the passkey calls.

- New: on `LoginFlowAuth`, `totpStatus()` → `TotpStatus(isEnabled,
  verifiedAt)`, `startTotpEnrollment({issuer})` → `TotpEnrollment(secret,
  otpauthUri, issuer)`, `confirmTotpEnrollment(code)`, `disableTotp(code)`
  and `regenerateRecoveryCodes()` → `List<String>`. Recovery codes need a
  recent sign-in: `StepUpRequired`, then `stepUp` and ask again.
- Breaking: `LoginFlowError` gains `InvalidTotpCode` (`401 INVALID_CODE`: a
  wrong code or a locked account) and `TotpAccountRefused(code)` (a coded
  `403`, e.g. `not_available_for_access_subject`); an exhaustive `switch`
  over `LoginFlowError` needs their cases.
- Docs: `doc/server-contract.md` §20, `doc/integration-guide.md` section
  10, README.
- Tests: the fake server answers the TOTP routes like `totp_handler.rs` and
  `recovery_code_handler.rs` (DPoP, `INVALID_CODE`, the recent-auth gate).

## 0.14.0

Access codes once, then passkeys: a subject signed in with an access code
(`person` or `device`) enrolls a passkey, and its next sign-in is
`signInWithPasskey()` with no code.

- Added: `ClientLoginOptions.isAccessCodeOffered`. `access_code` is now a
  client login method the server lists in the login options; it is
  redeemed with `signInWithAccessCode`, never shown as a sign-in button.
- Changed: the bundled UI offers "I have an access code" only when the app
  opts in (`SignInConfiguration.isAccessCodeOffered`) **and** the client's
  login methods list `access_code`; the server refuses a redemption from
  any other client (`unauthorized_client`). An access-code-only app whose
  client lacks it now shows "no sign-in method" instead of a code step the
  server refuses.
- Changed: `LoginFlowPasskeys` offers "Add a passkey" to every signed-in
  principal, an access-code `device` subject included. On an access-code
  session the platform's passkey sheet shows the subject's display name,
  else its external id — the server's own default.
- Added: `PasskeyAccountRefused(code)`. A coded `403` from the passkey
  account API (`/v1/user/passkeys*`) — passkeys off for the company,
  `passkey` not among the client's login methods — is this typed error,
  instead of `ServerResponseInvalid`; the passkey manager shows "Passkeys
  are not available for this account."
- Added: `PasskeyRejected`. A passkey sign-in the server refuses after the
  ceremony (`webauthn_assertion` with a `step_error`: a credential deleted
  after a new access code or a revocation, a policy, client or gate that
  refuses it) ends with this typed error, instead of
  `ServerResponseInvalid` ("step without options"), and never runs the
  ceremony again on that attempt. The bundled UI shows the invalid
  credentials message.
- Breaking: `PasskeysState.isEnrollmentOffered` and
  `LoginFlowStrings.passkeysSharedDevice` are removed (no principal is
  refused a passkey anymore); `LoginFlowStrings` gains
  `feedbackPasskeysUnavailable`, so a custom implementation must add it.
- Docs: `doc/integration-guide.md` has the "code once, then passkey" recipe
  for device and person apps; `doc/server-contract.md` lists `access_code`
  among the login methods, passkeys for access-code subjects and the
  `unauthorized_client` refusal of a client without `access_code`.
- Tests: the fake server refuses a redemption from a client without
  `access_code`, lets an access-code subject enroll a passkey and signs it
  in again from that credential, can delete a subject's passkeys, and can
  answer the passkey account API with a coded `403`.

## 0.13.0

Contract audit against `loginflow_api` `main`: every flow checked field by
field, the fake server the tests run against now answers what the server
answers, and the documentation covers integrating an app end to end.

- Breaking: `signInWithAccessCode` no longer takes `organization`. The
  server issues an access code's authorization code without one (and
  without a `redirect_uri`), so the parameter was silently ignored; the
  session starts in the subject's only organization, or none — then
  `switchOrganization`.
- Fixed: an access code is redeemed without `redirect_uri`. An app that
  configured `LoginFlowConfig.redirectUri` (browser fallback) and redeemed
  an access code got `OAuthProtocolError(invalid_grant)` (`redirect_uri
  mismatch`) at the token endpoint.
- Fixed: `selectMethod` with a step the user answers by typing a value
  (`password`, `totp`, `recoveryCode`, `temporaryAccessPass`) switches the
  prompt locally, on the same `auth_session`, instead of sending
  `method=<step>`, which the server answers `400 invalid_request` (it takes
  the typed value on any step). `emailOtp`, `magicLink` and
  `webauthnIdentify` are still sent: they act on the server.
- Fixed: a refusal of an OAuth resource endpoint (organizations, device and
  global logout) — `401` with only a `WWW-Authenticate` challenge, no body —
  is `OAuthProtocolError(statusCode, code)` read from the challenge (e.g.
  `invalid_token`), instead of `ServerResponseInvalid` ("the body is not
  valid JSON").
- Fixed: `signOut(SignOutScope.device)` and `signOut(SignOutScope.everywhere)`
  on a session that already ended on the server (another app's device
  logout, a global logout, an administrator) clear the local session and the
  shared SSO entry and answer `SignedOut(reason: sessionRevoked)`, instead
  of failing and leaving the dead session signed in until its next refresh.
- Fixed: the Linux loopback page's title no longer names LoginFlow: the
  library is white-label.
- Docs: `doc/integration-guide.md`, a step-by-step guide to integrate a
  Flutter app per platform, and how to use per-API tokens, organizations,
  step-up, members and email change, with the RutaFácil apps as examples.
  `doc/server-contract.md` now states what `loginflow_api` answers where it
  differs from the contract (Apple/Facebook `upstream_flow=browser`, legal
  links in the login options, `auth_session` never in the token response,
  `method=password`), and adds the magic link (§5.8). Every exported member
  has dartdoc.
- Tests: the fake server rotates `auth_session` on every `403`, keeps the
  presented one as the step-up handle of a completed transaction, opens a
  new transaction for a step-up, never returns `auth_session` from the
  token endpoint, answers a continuation without a recognized step with
  `400 invalid_request`, issues access-code codes without `redirect_uri` or
  organization, and refuses tokens of ended sessions on every resource with
  `401` + `WWW-Authenticate` and no body, the logout endpoints included.

## 0.12.0

Email change (`doc/server-contract.md` §19): a person changes their own
email from any product, through LoginFlow's `/v1/app/email-change`.

- New: `startEmailChange(newEmail)` → `EmailChangeStarted(expiresAt,
  confirmCurrent)` and `confirmEmailChange(code, {currentCode})` →
  `EmailChangeConfirmed(email, isEmailVerified)` on `LoginFlowAuth`, with
  LoginFlow's own token like the members calls. A confirmed change refreshes
  the session, so a new `SignedIn` carries the new email.
- New: `StepUpRequirement.isStrongRequired` — the start's `StepUpRequired`
  asks for a second factor (`acr_values`) or only a recent sign-in. Call
  `stepUp(requirement)`, then start again.
- Breaking: `LoginFlowError` gains `InvalidEmailChangeCode` (every refused
  confirmation, generic) and `InvalidEmailAddress` (a refused new address);
  an exhaustive `switch` over `LoginFlowError` needs their cases. A fourth
  start within the hour is the existing `RateLimited(retryAfter)`.

## 0.11.0

Members (`doc/server-contract.md` §18): any product's "Team" screen on
LoginFlow's delegation rules, with no product-specific code.

- New: `listGrantableRoles`, `listMembers`, `inviteMember`, `grantRole` and
  `revokeAssignment` on `LoginFlowAuth`, over `/v1/app/members`, with the
  models `GrantableRoles`, `GrantableRole`, `MembersPage`,
  `OrganizationMember`, `MemberIdentity`, `MemberAssignment`, `MemberRole`,
  `MemberInvitation` and `InvitationStatus`.
- New: every members call uses LoginFlow's own token, asked with
  `resource=<issuer>` on the session's refresh family and DPoP key and
  cached apart from the API tokens (it never appears in
  `session.accessClaims`). The session's own token is not used: for a client
  with exactly one API its audience is that API, which the members API
  refuses.
- Breaking: `LoginFlowError` gains `DelegationDenied(code, statusCode)`
  (`DelegationDenialCode`); an exhaustive `switch` over `LoginFlowError`
  needs its case.

## 0.10.0

Organizations and per-API access tokens (`doc/server-contract.md` §17).
Breaking: the single session-wide access token is gone.

- Breaking: `LoginFlowAuth.accessToken()` and
  `authorizeResourceRequest({method, uri})` are removed. Use
  `accessTokenFor(String api)` and `authorizedHeadersFor(String api,
  {method, uri})`: one token per API, refreshed with `resource=<api>`
  (RFC 8707) on the same refresh family and DPoP key, cached per API.
  Refreshes are queued so a rotated refresh token is never presented twice.
  `shouldRetryResourceRequest` is unchanged.
- New: `LoginFlowConfig.apis` (JSON `apis`) declares the audiences of the
  APIs the app calls; any other is refused locally with
  `ConfigurationInvalid`, before a request. `validate()` refuses an empty or
  repeated audience.
- New: `InvalidTarget(api)` when the server answers `invalid_target` for an
  API not linked to the client; the session and the other APIs keep
  working.
- New: every sign-in method takes `organization:` (native challenge opening
  and the hosted authorization URL). `listOrganizations()` reads
  `GET {organizations_endpoint}` (`OrganizationList`, `Organization`,
  `OrganizationKind`); `switchOrganization(id)` refreshes with
  `organization`, drops every cached API token and fails with
  `OrganizationUnavailable(id)` (session kept) when the user holds no role
  there. A step-up and a re-authentication open in the active organization
  (`StoredSession.organizationId`).
- New: `LoginFlowSession.accessClaims` — `AccessTokenClaims`
  (`organizationId`, `organizationExternalId`, `permissions`,
  `isPermissionsOverage`) per API, decoded from the token WITHOUT
  verification: for the UI only, never for access decisions. A new
  `SignedIn` is emitted when they change.
- New: `DiscoveryDocument.organizationsEndpoint` (`organizations_endpoint`).

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
