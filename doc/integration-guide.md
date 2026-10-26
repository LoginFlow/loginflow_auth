# Integrating a Flutter app with `loginflow_auth`

A step-by-step guide, from registering the app on LoginFlow to calling your
own API with the user's token. Everything here matches `loginflow_auth`
0.15.0 and `loginflow_api` `main`; where the server does not do something
yet, the guide says so. The worked examples come from the RutaFácil apps,
which use the library in production:

| App | Platforms | Signs in with |
|---|---|---|
| `Rutafacil/apps/panel` | web, Android, macOS | email + password, passkeys, step-up; members and email change |
| `Rutafacil/apps/consola` | web, Android | the same as the panel |
| `Rutafacil/apps/driver`, `Rutafacil/apps/recorder` | Android, web | an access code once, then a passkey (no email, no password) |

The wire contract behind every call is
[`server-contract.md`](server-contract.md); the API reference is the
dartdoc of `package:loginflow_auth/loginflow_auth.dart`.

## 1. Register the app on LoginFlow

Done once per app, by an operator of the company, in the LoginFlow panel
or through the control plane (`/v1/control/…`, a recent strong sign-in
required). Every value below is per OAuth client: an app that ships on
several platforms usually has one client per platform family (one native,
one web).

1. **Application and APIs.** The company's application exists, and every
   API the app calls is registered on it with its audience (e.g.
   `APP-S0R6Y0T0X6`).
2. **OAuth client** — `POST /v1/control/oauth-clients`:
   - `client_type: "public"` (an app holds no secret);
   - `application_type: "native"` for Android, iOS, macOS and Linux;
     `"web"` for a Flutter web app;
   - `redirect_uris`: the browser-step callback of each platform (see
     section 3); `post_logout_redirect_uris` only if the app uses
     `SignOutScope.browser`;
   - `login_methods`: any of `password`, `email_otp`, `magic_link`,
     `passkey`, `access_code`, `google`, `microsoft`, `apple`, `facebook`
     (the default is `password`, `email_otp`, `passkey`). The built-in UI
     and the server both enforce this list. An app whose people or devices
     come from your backend lists `access_code` (plus enable access codes
     on the application) and, for "code once, then passkey", `passkey` —
     and no human method it never uses.
3. **First party** — `PATCH /v1/control/oauth-clients/{client_id}/first-party`
   `{"first_party": true}`, for an app the company owns. It skips the
   hosted consent page and is required for browser origins (section 3.4),
   access codes and Native SSO. It also makes DPoP mandatory for a
   `native` client and for a client with browser origins, so the app must
   set `enableDpop: true` (section 2).
4. **APIs of the client** — `PUT /v1/control/oauth-clients/{client_id}/apis`
   with the API ids the app may ask tokens for. A `resource` outside this
   list is refused (`InvalidTarget`).
5. **Platform extras**, when they apply:
   - web: the app's exact origins (section 3.4);
   - Android and iOS passkeys: the app's identity for the company's
     passkey domain (section 3.5);
   - Native SSO between apps of the same publisher: an SSO group with both
     clients (`/v1/control/sso-groups`).

## 2. Add the dependency and create the client

```yaml
dependencies:
  loginflow_auth:
    git:
      url: https://github.com/LoginFlow/loginflow_auth.git
      ref: v0.15.0
```

Create ONE `LoginFlowAuth` for the app's lifetime, with
`LoginFlowPlatform.createAuth`: it wires the platform's secure storage,
DPoP key, system browser and passkeys. The RutaFácil panel (web, email and
password, one API):

```dart
LoginFlowAuth createAuth() => LoginFlowPlatform.createAuth(
  config: LoginFlowConfig(
    issuer: Uri.parse(RfEnv.loginFlowIssuer),
    clientId: RfEnv.loginFlowClientId,
    scopes: const ['profile', 'email', 'offline_access'],
    apis: const [RfEnv.loginFlowApi],
    redirectUri: Uri.parse(RfEnv.loginFlowRedirectUri),
    // LoginFlow binds every token of a first-party web client to a DPoP
    // key; the API checks the proof against PUBLIC_BASE_URL.
    enableDpop: true,
  ),
);
```

The RutaFácil driver app (Android, access codes only):

```dart
LoginFlowAuth createAuth() => LoginFlowPlatform.createAuth(
  config: LoginFlowConfig(
    issuer: Uri.parse(RfEnv.loginFlowIssuer),
    clientId: RfEnv.loginFlowClientId,
    apis: const [RfEnv.loginFlowApi],
    // An access-code session is bound to this phone's DPoP key; the API
    // checks the proof of every request against it.
    enableDpop: true,
  ),
  enablePasskeys: false,
);
```

- `issuer`: `LoginFlowEnvironment.production.issuer` /
  `.development.issuer`, or your own deployment's issuer.
- `apis`: the audiences of the APIs the app calls; any other is refused
  locally before a request.
- `redirectUri`: needed only for browser steps (Microsoft, sign-up,
  password reset, Google/Apple/Facebook without a native source, the web's
  authorization-code redirect). An app without it — like the driver app —
  simply never offers them.
- `enableDpop: true` for every first-party native client and every client
  with browser origins (section 1): the server refuses their tokens without
  a proof. Leave it off only for a client the server does not require DPoP
  from.

Then start it once, and follow its states:

```dart
_authStates = _auth.states.listen(_onAuthState);
// On the web, pass the URL the page opened at: a browser-step callback is
// completed from it. Read it before the router rewrites the address.
final restored = await _auth.initialize(launchUri: Uri.base);
```

`initialize` restores the stored session (a DPoP-bound one is refreshed
with its key first), completes a callback, or reports a Native SSO session
of a sibling app (`SsoAvailable`). The states are `AuthInitializing`,
`SignedOut(reason)`, `SsoAvailable`, `ChallengeRequired(prompt, purpose)`,
`AwaitingBrowser` and `SignedIn(session)`; route on `SignedIn` and
`SignedOut`, and let the sign-in screen follow the rest.

## 3. Platform setup

### 3.1 Android

1. **Package and signing.** Note the application id and the SHA-256 of
   every certificate the app is released with (Play App Signing's in
   production, not the local debug key). Passkeys and Native SSO depend on
   them.
2. **Redirect for browser steps** (skip if the app has none). Declare the
   library's callback activity for the redirect URI — an App Link is
   preferred (RFC 8252 §7.2), a private scheme
   (`com.acme.orders:/oauth/callback`) also works:

   ```xml
   <activity
       android:name="dev.loginflow.auth.browser.LoginFlowCallbackActivity"
       android:exported="true"
       android:theme="@android:style/Theme.Translucent.NoTitleBar">
       <intent-filter android:autoVerify="true">
           <action android:name="android.intent.action.VIEW" />
           <category android:name="android.intent.category.DEFAULT" />
           <category android:name="android.intent.category.BROWSABLE" />
           <data android:scheme="https"
                 android:host="app.acme.com"
                 android:path="/oauth/callback" />
       </intent-filter>
   </activity>
   ```

   Register the same URI in the client's `redirect_uris`, publish
   `/.well-known/assetlinks.json` on that host for an App Link, and keep
   `MainActivity` `launchMode="singleTop"` (the Flutter default). A
   callback that does not carry the pending `state` is ignored, so a forged
   navigation cannot end a sign-in in progress.
3. **Exclude the session from backups.** The session and the Native SSO
   entry are encrypted with a non-exportable Keystore key, so a restored
   copy can never be decrypted. The RutaFácil driver app's
   `res/xml/data_extraction_rules.xml` (Android 12+), referenced from
   `<application android:dataExtractionRules="@xml/data_extraction_rules"
   android:fullBackupContent="@xml/full_backup_content">`:

   ```xml
   <data-extraction-rules>
       <cloud-backup>
           <exclude domain="sharedpref" path="dev.loginflow.auth.private.xml" />
           <exclude domain="sharedpref" path="dev.loginflow.auth.sso.xml" />
       </cloud-backup>
       <device-transfer>
           <exclude domain="sharedpref" path="dev.loginflow.auth.private.xml" />
           <exclude domain="sharedpref" path="dev.loginflow.auth.sso.xml" />
       </device-transfer>
   </data-extraction-rules>
   ```

   and the same two `<exclude>` lines in `res/xml/full_backup_content.xml`
   (Android 11 and older).
4. **Passkeys**: section 3.5. **Magic link** and **Native SSO**: the
   README's [Android](../README.md#android) and
   [Magic link](../README.md#magic-link-android-app-links--ios-universal-links)
   sections.

What the app gets: the session in Keystore-encrypted preferences, the DPoP
key in the Android Keystore (StrongBox when the device has one), browser
steps in a Custom Tab, passkeys through Credential Manager.

### 3.2 iOS

Implemented by the plugin's shared Darwin sources (Keychain, Secure
Enclave, `ASWebAuthenticationSession`, AuthenticationServices passkeys).
None of the RutaFácil apps ships on iOS, so its device checks are the
README's manual test plan (rows 7, 8, 13 and 23).

1. **Redirect for browser steps**: a claimed `https` redirect (Associated
   Domains `applinks:` + `apple-app-site-association`, iOS 17.4+), or a
   private reverse-domain scheme on older iOS. Nothing goes in
   `CFBundleURLTypes`: `ASWebAuthenticationSession` receives the callback
   itself.
2. **Storage**: nothing to configure. Items are
   `AfterFirstUnlockThisDeviceOnly` and never synchronized to iCloud.
3. **Passkeys**: section 3.5. **Native SSO**: the shared keychain group,
   README [iOS](../README.md#ios).

### 3.3 macOS and other desktops

- **macOS**: as iOS. Add `com.apple.security.network.client` and the
  `keychain-access-groups` to `DebugProfile.entitlements` and
  `Release.entitlements`.
- **Linux**: register a `native` client with a **fixed-port** loopback
  redirect (`http://127.0.0.1:53682/oauth/callback`; the server compares
  redirect URIs exactly, port included) and use exactly that URI. The
  session and a software DPoP key live in the Secret Service keyring
  (`libsecret-1-dev` to build, a running, unlocked Secret Service at run
  time). No passkeys (`PasskeyFailed(notSupported)`) and no Native SSO.
  The page the browser shows after the callback names no product.
- **Windows**: not supported for first-party clients. There is no secure
  storage, browser or DPoP key implementation: the session stays in memory
  and, without a DPoP key, the server refuses the sign-in of a client that
  requires DPoP.

### 3.4 Web

The web runs the same native sign-in as the apps, from origins the client
registered, with the session bound to a non-extractable WebCrypto key.

On the server, once per web client:

1. The client is first-party (section 1) and lists the app's exact
   origins: `PATCH /v1/control/oauth-clients/{client_id}/web-origins`
   `{"allowed_web_origins": ["https://panel.rutafacil.app"]}` — `https`
   only (`http://localhost` only in a development deployment), no path.
   This opens CORS on `POST /oauth2/authorize-challenge` for those origins
   only, makes DPoP mandatory, and lists them as related origins of the
   company's passkey domain.
2. The same origins are in the server's `CORS_ALLOWED_ORIGINS`, which
   covers discovery, JWKS, login options, token, revocation, organizations,
   device and global logout, and the `/v1/user` and `/v1/app` scopes.
3. An `https` redirect URI on the app's origin for the browser steps.

In the app: `enableDpop: true` (without it the session is kept in memory
only) and `initialize(launchUri: Uri.base)`. For passkeys, load Corbado's
`bundle.js` in `web/index.html` **before** `flutter_bootstrap.js`; see the
README's [Web](../README.md#web) section for the details (tabs, reloads,
the 24 h absolute lifetime of web refresh tokens).

### 3.5 Passkeys on Android and iOS

A passkey belongs to the company's relying-party domain
(`<slug>.id.loginflow.dev` or its custom domain), not to the app, so the OS
must be told the app may use it. An operator registers the app on the
client:

```http
PATCH /v1/control/companies/{company_id}/oauth-clients/{client_id}/passkey-app-registration

{
  "android_package_name": "com.acme.orders",
  "android_cert_sha256": ["3F:9A:…:0E"],
  "ios_team_id": "ABCDE12345",
  "ios_bundle_id": "com.acme.orders"
}
```

LoginFlow then publishes `assetlinks.json` and
`apple-app-site-association` on the passkey domain. `android_cert_sha256`
is uppercase, colon-separated hex; list every certificate the app is
signed with (Play App Signing included): a passkey ceremony from an
unregistered certificate fails (`securityError` / `domainNotAssociated`).
On iOS add the Associated Domains entry `webcredentials:<passkey domain>`.

Passkeys then work from `LoginFlowPlatform.createAuth` with no code; pass
`enablePasskeys: false` for an app that does not offer them.

## 4. Sign in

Two ways, same session:

- **The built-in UI**: `LoginFlowSignInSetup.install(auth: …,
  configuration: …)` once, then show `LoginFlowSignIn(onSignedIn: …)`. It
  reads the server's login options and offers only what both the
  configuration and the server allow. See the README's
  [Ready-to-use sign-in UI](../README.md#ready-to-use-sign-in-ui).
- **Your own screens** over the API: `signInWithPassword`,
  `requestEmailOtp` / `submitEmailOtp`, `signInWithPasskey`,
  `signInWithGoogle` / `Microsoft` / `Apple` / `Facebook`,
  `signInWithTemporaryAccessPass`, `signInWithAccessCode`,
  `signInWithBrowser`. Each returns `Result<AuthState, LoginFlowError>`;
  a `ChallengeRequired` state asks for the next step (`submitTotp`,
  `submitRecoveryCode`, …). `selectMethod` switches to one of the prompt's
  alternatives: typed steps (password, TOTP, recovery code) switch locally,
  `emailOtp` emails a code.

The driver app redeems an access code and binds the phone:

```dart
final redeemed = await _auth.signInWithAccessCode(code); // "K7QM-4XPR"
if (redeemed case Err(:final error)) {
  return Err(_refusalOf(error)); // InvalidAccessCode, AccessCodeThrottled, …
}
```

Every sign-in method but `signInWithAccessCode` takes `organization:` to
start the session in one organization (section 6).

### 4.1 Code once, then passkey (device and person apps)

For an app whose subjects live in your backend (a driver, a recorder, a
kiosk): the first sign-in on a phone uses the access code, every later one
a passkey (fingerprint or screen lock). Requirements: the client lists
`access_code` and `passkey` (section 1), the app is registered for the
passkey domain (section 3.5), `enableDpop: true`, and passkeys are not
disabled (`enablePasskeys` left at its default).

1. **Redeem the code.** `signInWithAccessCode(code)` → `SignedIn`, the
   identity carries `externalSubject` / `subjectKind` / `subjectProfile`.
   Bind the phone to the subject in your backend as usual.
2. **Enroll a passkey within 300 s.** Right after the redemption the
   session is recent enough for the server's gate; offer it once ("Protect
   your access with your fingerprint") and call:

   ```dart
   final identity = (_auth.state as SignedIn).session.identity;
   final name = identity.name ?? identity.externalSubject ?? identity.subject;
   final enrolled = await _auth.enrollPasskey(
     username: name,
     displayName: name,
   );
   ```

   `username`/`displayName` are what the platform sheet shows; the
   subject's display name, else its external id, is the server's own
   default. If it fails, the phone simply keeps the code session:
   `PasskeyFailed(notSupported | notConfigured)` (no passkeys on this
   phone or build), `PasskeyFailed(userCancelled)` (the user said no),
   `PasskeyAccountRefused(code)` (the client does not list `passkey`, or
   passkeys are off for the company), `StepUpRequired` (more than 300 s
   went by — do not loop; offer it again after the next code sign-in).
3. **When the session has ended**, on start (`SignedOut`, or a refresh
   that failed with `SessionRevoked`): try the passkey first, with no
   arguments — the credential names the subject:

   ```dart
   final signedIn = await _auth.signInWithPasskey();
   ```

   On `SignedIn` the session is the same subject, DPoP-bound to this
   phone's key, exactly as a code gives it; load the subject's data from
   `externalSubject`. Only offer this step while the login options list
   `passkey` (`fetchLoginOptions()` → `allows('passkey')`): a client
   without it answers `OAuthProtocolError(code: 'unsupported_client')`.
4. **Fall back to the code.** Any failure of step 3 — no passkey on this
   phone (`PasskeyFailed(noCredentialsAvailable)`), the user dismissed the
   sheet, or the server refused the passkey (`PasskeyRejected`: deleted on
   the server, or the subject no longer passes the client's gate) — shows
   the code entry
   ("Use a code"). Your backend deletes a subject's passkeys whenever it
   issues a new code with `revoke_existing_sessions: true`, revokes or
   deletes the subject, so an old phone's passkey stops working with no
   extra call.

A synced passkey used on another phone signs in with that phone's DPoP
key (`cnf.jkt`), so a backend that binds a subject to one device refuses
it there; keep that check.

## 5. Call your API with the user's token

Each API gets its own access token, carrying only that API's permissions
in the active organization. Never build the `Authorization` header
yourself: `authorizedHeadersFor` returns `Authorization: DPoP <token>` and
a fresh `DPoP` proof for exactly that request (or `Bearer` without DPoP).
Report every answer to `shouldRetryResourceRequest`, which keeps the API's
`DPoP-Nonce` and says when to send the request once more. The panel:

```dart
Future<Result<Map<String, String>, ApiFailure>> authorizeRequest(
  String method,
  Uri uri,
) async {
  final authorized = await _auth.authorizedHeadersFor(
    RfEnv.loginFlowApi,
    method: method,
    uri: uri,
  );
  if (authorized case Err(:final error)) return Err(_failureOf(error));
  return Ok(authorized.data.toHeaders());
}

bool shouldRetryRequest({
  required Uri uri,
  required int statusCode,
  String? dpopNonce,
  String? wwwAuthenticate,
}) => _auth.shouldRetryResourceRequest(
  uri: uri,
  statusCode: statusCode,
  dpopNonce: dpopNonce,
  wwwAuthenticate: wwwAuthenticate,
);
```

The HTTP client calls `authorizeRequest` before every request — a retry
included, a proof is single use — and, when `shouldRetryRequest` answers
`true`, sends the request once more with new headers.

- `accessTokenFor(api)` gives the bare token when a header is not what you
  need. Tokens are cached per API and refreshed when needed; refreshes
  never overlap.
- `session.accessClaims[api]` decodes `org_id`, `org_ext`, `permissions`
  and `permissions_overage` of that API's token **without verification**,
  for the UI only. Your API decides access.
- `InvalidTarget(api)`: the API is not linked to this client (section 1,
  step 4). `SessionRevoked`: the refresh was refused; the library has
  already signed out.

## 6. Organizations

The organization is the product's unit of scope (a client company, a
school). A session works in one at a time; without an `organization:` at
sign-in, the server activates the user's only one, or none when there are
several. The panel lists them after sign-in and switches:

```dart
final listed = await _auth.listOrganizations();
switch (listed) {
  case Ok(data: OrganizationList(:final organizations))
      when organizations.isEmpty:
    await _refuse(SessionRefusal.noAccess);
  case Ok(data: OrganizationList(organizations: [final only])):
    await _switchTo(subject, only.id);
  case Ok(data: OrganizationList(:final organizations)):
    _offerChoice(organizations); // the person picks one
  case Err(:final error):
    // A network failure, or the token was refused (the session ended
    // elsewhere): OAuthProtocolError(statusCode: 401, code: 'invalid_token').
    _showFailure(error);
}

Future<void> _switchTo(String subject, String organizationId) async {
  final switched = await _auth.switchOrganization(organizationId);
  switch (switched) {
    case Ok():
      await _fetch(subject);
    case Err(error: OrganizationUnavailable()):
      await _offerOrganizations(subject); // no assignment there any more
    case Err(:final error):
      _showFailure(error); // the session is kept
  }
}
```

`switchOrganization` refreshes the session with `organization`, drops every
cached API token (they belonged to the previous organization) and empties
`session.accessClaims`; the next `authorizedHeadersFor` gets a token for the
new one. On `OrganizationUnavailable` the session keeps its organization.

## 7. Step-up (RFC 9470)

Sensitive calls (enrolling a passkey, members writes, starting an email
change, your own API if it asks) may answer that the sign-in is too old or
not strong enough. The library reports it as `StepUpRequired(requirement)`;
`requirement.isStrongRequired` tells a second factor (`acr_values`) from a
recent sign-in (`max_age` alone). Run `stepUp(requirement)`, answer the
challenge it opens, then send the call again — once. The panel's
repository and the flow around it:

```dart
Future<Result<AuthState, LoginFlowError>> stepUp(
  StepUpRequirement requirement,
) => _auth.stepUp(requirement);

Future<Result<AuthState, LoginFlowError>> requestEmailCode() =>
    _auth.selectMethod(ChallengeStep.emailOtp); // "email me a code instead"
```

```dart
case Err(error: StepUpRequired(:final requirement)) when !isRetry:
  await confirmIdentityThen(requirement, () => _start(email, isRetry: true));
```

The step-up always asks the primary factor again (the password, or an
email code), then the TOTP when the requirement is strong. An account
without TOTP meets a strong requirement with its passkey instead, when the
company allows passkeys as a first factor; with neither, the server answers
`OAuthProtocolError(code: 'unmet_authentication_requirements')`. It ends in a new `SignedIn` for
the same user; its tokens replace the cached ones, so the retry presents
the new sign-in. `cancelChallenge()` drops it and keeps the session. For
your own API, parse its `WWW-Authenticate` with
`StepUpRequirement.fromWwwAuthenticate`.

## 8. Members ("Team" screen)

Any product can let a person manage who holds which role in the
organizations their own roles reach; LoginFlow's delegation rules decide
every grant. The panel's repository:

```dart
Future<Result<GrantableRoles, LoginFlowError>> grantableRoles(
  String organizationId,
) => _auth.listGrantableRoles(organizationId: organizationId);

Future<Result<List<OrganizationMember>, LoginFlowError>> members(
  String organizationId,
) async {
  final members = <OrganizationMember>[];
  while (true) {
    final page = await _auth.listMembers(
      organizationId: organizationId,
      limit: 100,
      offset: members.length,
    );
    switch (page) {
      case Ok(data: MembersPage(:final items, :final total)):
        members.addAll(items);
        if (items.isEmpty || members.length >= total) return Ok(members);
      case Err(:final error):
        return Err(error);
    }
  }
}

Future<Result<MemberInvitation, LoginFlowError>> invite({
  required String organizationId,
  required String email,
  required String roleId,
}) => _auth.inviteMember(
  organizationId: organizationId,
  email: email.trim().toLowerCase(),
  roleId: roleId,
);

Future<Result<void, LoginFlowError>> revoke(String assignmentId) =>
    _auth.revokeAssignment(assignmentId);
```

- Hide the screen when `GrantableRoles.roles` is empty (no grant power
  there).
- Offer "remove" only when `MemberAssignment.manageable`.
- Every write needs a recent strong sign-in: handle `StepUpRequired` as in
  section 7.
- A refusal is `DelegationDenied(code, statusCode)`; `code` names the rule
  (`roleNotGrantable`, `privilegeExceedsGrantor`,
  `selfAssignmentForbidden`, …), so the UI can say why without parsing
  text.
- `grantRole(organizationId:, principalId:, roleId:, expiresAt:)` adds a
  role to an existing member.

The calls use LoginFlow's own token (`resource=<issuer>`), asked on the
same refresh family and key; the app does nothing for it.

## 9. Email change

A person changes their own email. Start with the new address; LoginFlow
sends a code there and, for an account without a second factor, another
one to the current address (`EmailChangeStarted.confirmCurrent`). The
panel's repository:

```dart
Future<Result<EmailChangeStarted, LoginFlowError>> startEmailChange(
  String newEmail,
) => _auth.startEmailChange(newEmail);

Future<Result<EmailChangeConfirmed, LoginFlowError>> confirmEmailChange(
  String code, {
  String? currentCode,
}) => _auth.confirmEmailChange(code, currentCode: currentCode);
```

- The start may answer `StepUpRequired` (strong for an account with a
  second factor, recent otherwise): step up and start again (section 7).
- `InvalidEmailAddress`: malformed, disposable, or the current address.
  `InvalidEmailChangeCode`: any refused confirmation, deliberately
  generic. `RateLimited`: more than three starts in an hour.
- After the confirmation the library refreshes the session, so a new
  `SignedIn` carries the new email; the server has ended every OTHER
  session of the person. The panel notices the new email in its
  `SignedIn` handler and re-reads its own session in place.

## 10. Authenticator app (TOTP)

A person turns an authenticator app on or off as their second factor, and
gets recovery codes for it. The calls use the session's own token, like the
passkey ones; an access-code session has no account to hold one
(`TotpAccountRefused`). A repository:

```dart
Future<Result<TotpStatus, LoginFlowError>> status() => _auth.totpStatus();

Future<Result<TotpEnrollment, LoginFlowError>> startEnrollment() =>
    _auth.startTotpEnrollment(issuer: 'Acme Console');

Future<Result<void, LoginFlowError>> confirmEnrollment(String code) =>
    _auth.confirmTotpEnrollment(code);

Future<Result<void, LoginFlowError>> disable(String code) =>
    _auth.disableTotp(code);

Future<Result<List<String>, LoginFlowError>> recoveryCodes() =>
    _auth.regenerateRecoveryCodes();
```

- `TotpEnrollment.otpauthUri` is the QR code's content, verbatim;
  `secret` is for typing it by hand. Nothing changes until
  `confirmTotpEnrollment` succeeds with a code the app produced; a new
  start replaces the pending secret. `issuer` names the entry in the app
  (without it, the application's name).
- `InvalidTotpCode`: a wrong code, or the account is locked after too many
  wrong codes or passwords.
- Turning it on issues no recovery codes: ask `regenerateRecoveryCodes()`
  right after and show them once. It needs a recent sign-in: handle
  `StepUpRequired` as in section 7.
- With TOTP on, the next sign-in and every strong step-up ask for its code
  (or a recovery code).

## 11. Sign out

```dart
final ended = await _auth.signOut(SignOutScope.app);
```

| Scope | Ends |
|---|---|
| `app` | this app's session (its refresh token is revoked) |
| `device` | the device session: every app sharing it through Native SSO; siblings sign out at their next refresh or resume (`verifyDeviceSession`) |
| `everywhere` | every session of the user in the company |
| `browser` | the hosted-login browser session (RP-initiated logout; needs `postLogoutRedirectUri`) |

The local session always ends. When the server already ended the session
(another app's device logout, a global logout, an administrator), `device`
and `everywhere` clear it locally and report
`SignedOut(reason: sessionRevoked)`. Clients that registered a back-channel
logout URI are notified by the server; the library is not involved.

## 12. Errors

Every operation returns `Result<T, LoginFlowError>`; expected failures
never throw. `LoginFlowError` is sealed, so a `switch` over it is checked
by the compiler. The ones an app usually handles:

| Error | Meaning |
|---|---|
| `NetworkFailure` | no HTTP answer (offline, timeout) |
| `RateLimited(retryAfter)` | too many attempts; wait `retryAfter` |
| `SessionRevoked` | the refresh was refused; already signed out |
| `StepUpRequired(requirement)` | section 7 |
| `InvalidTarget(api)` / `OrganizationUnavailable(id)` | sections 5 and 6 |
| `DelegationDenied(code, statusCode)` | section 8 |
| `InvalidEmailAddress` / `InvalidEmailChangeCode` | section 9 |
| `InvalidTotpCode` / `TotpAccountRefused(code)` | section 10 |
| `InvalidAccessCode` / `AccessCodeThrottled` / `AccessCodesUnavailable` | access codes |
| `PasskeyAccountRefused(code)` | the passkey account API refused with a coded `403` (section 4.1) |
| `PasskeyRejected` | the server did not accept a passkey sign-in: deleted credential, policy, client or gate (section 4.1) |
| `PasskeyFailed(reason)` / `UpstreamFailed(provider, reason)` / `BrowserFailed(reason)` | a platform ceremony failed or was cancelled |
| `OAuthProtocolError(statusCode, code)` | any other OAuth refusal, with the server's `error` code |
| `ConfigurationInvalid` / `UnsupportedByServer(feature)` | the app's configuration or the server's discovery cannot do it |

## 13. Known gaps of the server

As of `loginflow_api` `main`:

- `signInWithApple` / `signInWithFacebook` without a native source (Apple
  on Android, either on the web) fail with
  `OAuthProtocolError(code: 'unsupported_client')`: the server has no
  browser hand-off for those two providers yet.
- The login options do not carry the client's `policy_uri`/`tos_uri`, so
  the built-in UI shows no legal footer.
