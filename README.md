# loginflow_auth

Flutter client library for **LoginFlow**, the OAuth 2.0 / OpenID Connect
provider. It gives first-party apps:

- **Native sign-in** (password, email one-time code, magic link, TOTP and
  recovery codes, passkeys, a Temporary Access Pass, access codes, Google,
  Microsoft, Apple and Facebook) through the OAuth 2.0 *Authorization Challenge Endpoint*
  (draft-ietf-oauth-first-party-apps-04), ending in an authorization code
  redeemed with PKCE S256 — the same flow on Android, iOS, macOS, Linux and
  the web (from origins the client registered, see [Web](#web)).
- **Passkeys** (WebAuthn L3 — Android Credential Manager, iOS/macOS
  AuthenticationServices, the browser's WebAuthn API) work out of the box
  through `LoginFlowPlatform.createAuth`: no extra package, no platform
  code to write. **Google native sign-in** is one small optional package
  away (`loginflow_auth_google` — see [Google](#google)); without it,
  Google still works through the system browser.
- **In-app password reset**: an emailed code, the new password, then
  signed in — the library holds the session until the password is set
  ([Password reset (in-app)](#password-reset-in-app)). No browser.
- **System-browser fallback** (ASWebAuthenticationSession, Custom Tabs, a
  top-level redirect on the web) whenever the server answers
  `redirect_to_web`: Microsoft, sign-up. Never a WebView.
- **ID token validation** (signature through the issuer JWKS, `iss`, `aud`,
  `azp`, `nonce`, `exp`, `iat`) before any claim is trusted.
- **Token lifecycle**: in-memory access tokens, refresh with rotation,
  single-flight refresh, and a rejected refresh treated as a logout.
- **DPoP** (RFC 9449): tokens bound to a non-exportable platform key, and
  [the same DPoP headers for your own API](#calling-your-own-api-dpop)
  without reimplementing the proof.
- **Native SSO** (OpenID Connect Native SSO, draft 07) between apps of the
  same publisher: a shared `device_secret` + ID token, exchanged by each app
  for its own tokens (RFC 8693).
- **Four logout levels**: this app, the device session, the browser session
  (RP-initiated logout) and everywhere.
- An optional **ready-to-use sign-in UI** driven by a typed configuration.

**Integrating an app?** Follow
[`doc/integration-guide.md`](doc/integration-guide.md): registration on
the server, configuration per platform (Android, iOS, macOS, web, Linux)
and the everyday calls (per-API tokens, organizations, step-up, members,
email change), with the RutaFácil apps as worked examples.

The exact HTTP contract the library expects from the server is in
[`doc/server-contract.md`](doc/server-contract.md).

## Packages

| Package | What | Platforms |
|---|---|---|
| `loginflow_auth` | Core, platform layer, sign-in UI, and the real passkey adapter ([`CorbadoPasskeyAuthenticator`](lib/src/platform/webauthn/corbado_passkey_authenticator.dart), the `passkeys` pub package) | Android, iOS, macOS, web, Linux (Windows: see [Limitations](#limitations)) |
| `packages/loginflow_auth_google` | Optional native Google sign-in ([`NativeGoogleIdTokenSource`](packages/loginflow_auth_google/lib/src/native_google_id_token_source.dart): Credential Manager, `GIDSignIn`) — its own native plugin, so apps without Google carry no Google SDK | Android, iOS |
| `packages/loginflow_auth_apple` | Optional native Sign in with Apple ([`NativeAppleTokenSource`](packages/loginflow_auth_apple/lib/src/native_apple_token_source.dart), over the `sign_in_with_apple` pub package) | iOS, macOS |
| `packages/loginflow_auth_facebook` | Optional native Continue with Facebook ([`NativeFacebookTokenSource`](packages/loginflow_auth_facebook/lib/src/native_facebook_token_source.dart), over the `flutter_facebook_auth` pub package: Limited Login on iOS, classic login on Android) | Android, iOS |

Passkeys live in the main package because `CorbadoPasskeyAuthenticator` is a
pure-Dart adapter over a federated plugin (`passkeys`); it needed no native
code of its own, so there was no reason to split it into a second package
the way Google's is split. Google needs its own hand-written native
Credential Manager/`GIDSignIn` code (`packages/loginflow_auth_google`,
predates this release) — and that package depends on `loginflow_auth`, so
`loginflow_auth` cannot default-wire it back without a circular dependency.
Apple and Facebook follow the same split, each over its own federated
plugin (`sign_in_with_apple`, `flutter_facebook_auth`) instead of
hand-written native code. Pass `enablePasskeys: false` to turn passkeys
off; there is nothing to turn off for Google/Apple/Facebook here since each
is opt-IN by adding its own package (see [Google](#google), [Apple](#apple),
[Facebook](#facebook)).

`import 'package:loginflow_auth/loginflow_auth_core.dart';` exposes only the
pure-Dart core (no Flutter imports, no `passkeys` dependency pulled in by
that import alone); `loginflow_auth.dart` adds the platform layer, the
passkey adapter and the UI.

```yaml
dependencies:
  loginflow_auth:
    git:
      url: git@github.com:LoginFlow/loginflow_auth.git
      ref: main
  # Only if the app offers Google sign-in:
  loginflow_auth_google:
    git:
      url: git@github.com:LoginFlow/loginflow_auth.git
      ref: main
      path: packages/loginflow_auth_google
  # Only if the app offers Sign in with Apple:
  loginflow_auth_apple:
    git:
      url: git@github.com:LoginFlow/loginflow_auth.git
      ref: main
      path: packages/loginflow_auth_apple
  # Only if the app offers Continue with Facebook:
  loginflow_auth_facebook:
    git:
      url: git@github.com:LoginFlow/loginflow_auth.git
      ref: main
      path: packages/loginflow_auth_facebook
```

## Platform support

| | Android | iOS | macOS | Web | Linux |
|---|---|---|---|---|---|
| Native sign-in (every challenge method) | yes | yes | yes | yes, from `allowed_web_origins` | yes |
| Session survives a restart | Keystore AES-GCM | Keychain | Keychain | `localStorage`, DPoP clients only | Secret Service (libsecret) |
| DPoP key | Keystore / StrongBox | Secure Enclave | Secure Enclave | non-extractable WebCrypto key in IndexedDB | software key in the Secret Service |
| Browser steps (`redirect_to_web`) | Custom Tabs | ASWebAuthenticationSession | ASWebAuthenticationSession | top-level redirect | default browser + loopback redirect |
| Passkeys | Credential Manager | AuthenticationServices | AuthenticationServices | WebAuthn (`passkeys_web`) | no (fails as `notSupported`) |
| Native SSO | yes | yes | yes | no (authorization-server cookie) | no |

## Quick start (API only)

```dart
final auth = LoginFlowPlatform.createAuth(
  config: LoginFlowConfig(
    issuer: LoginFlowEnvironment.production.issuer,
    clientId: 'acme-orders-mobile',
    scopes: const ['profile', 'email'],
    // The audience of every API this app calls (see "APIs, organizations
    // and permissions" below).
    apis: const ['APP-ACME0RDERS'],
    redirectUri: Uri.parse('https://acme.example.com/oauth/callback'),
    postLogoutRedirectUri: Uri.parse('https://acme.example.com/signed-out'),
    uiLocales: const ['es', 'en'],
  ),
  nativeSso: const NativeSsoOptions(
    appleAccessGroup: 'ABCDE12345.com.acme.loginflow.sso',
    androidSiblingAuthorities: ['com.acme.admin.loginflow.sso'],
  ),
);

await auth.initialize(); // restores the session or finds a Native SSO one

auth.states.listen((state) {
  switch (state) {
    case SignedIn(:final session):
      // session.identity.subject, .companyId, .email ...
    case SignedOut():
    case SsoAvailable():
    case ChallengeRequired():
    case AwaitingBrowser():
    case AwaitingResetCode(): // password reset, see below
    case AwaitingNewPassword():
    case AuthInitializing():
  }
});

final result = await auth.signInWithPassword(
  loginHint: 'ana@example.com',
  password: password,
);
result.when(
  ok: (state) => switch (state) {
    ChallengeRequired(:final prompt) => showStep(prompt.step), // e.g. TOTP
    _ => null,
  },
  err: (error) => showError(error),
);

// Calling your API: always ask for a fresh token for THAT API.
final token = await auth.accessTokenFor('APP-ACME0RDERS'); // refreshes when needed
```

Every operation returns `Result<T, LoginFlowError>`; `LoginFlowError` is a
sealed hierarchy, so a `switch` over it is exhaustive.

Challenge steps: `requestEmailOtp`, `submitEmailOtp`, `resendEmailOtp`,
`submitPassword`, `submitTotp`, `submitRecoveryCode`, `selectMethod`,
`signInWithGoogle`, `signInWithMicrosoft`, `signUp`, `cancelChallenge`.
Password reset: `startPasswordReset`, `submitResetCode`, `resendResetCode`,
`setNewPassword`, `cancelPasswordReset`. Step-up: `auth.stepUp(StepUpRequirement(acrValues: ['mfa']))`
or `StepUpRequirement.fromWwwAuthenticate(header)` from a 401 of your API
(RFC 9470).

### Calling your own API (DPoP)

With `enableDpop: true` the access token is bound to the app's DPoP key:
your API must receive `Authorization: DPoP <token>` plus a `DPoP` proof for
that exact request, never a bare `Bearer`. The library builds both — with
the cached server nonce — so the app does not reimplement RFC 9449:

```dart
Future<http.Response?> getOrders(LoginFlowAuth auth, Uri uri) async {
  Future<http.Response?> send() async {
    final authorization = await auth.authorizedHeadersFor(
      'APP-ACME0RDERS',
      method: 'GET',
      uri: uri,
    );
    return authorization.when(
      ok: (credentials) => http.get(uri, headers: credentials.toHeaders()),
      err: (_) async => null, // NotSignedIn / SessionRevoked: show sign-in
    );
  }

  final first = await send();
  if (first == null) {
    return null;
  }
  final shouldRetry = auth.shouldRetryResourceRequest(
    uri: uri,
    statusCode: first.statusCode,
    dpopNonce: first.headers['dpop-nonce'],
    wwwAuthenticate: first.headers['www-authenticate'],
  );
  return shouldRetry ? send() : first;
}
```

- `authorizedHeadersFor(String api, {required String method, required Uri
  uri})` → `Future<Result<ResourceAuthorization, LoginFlowError>>`: takes
  the token of `api` ([`accessTokenFor`](#apis-organizations-and-permissions),
  refreshed when needed) and returns `authorization` (`DPoP …`, or `Bearer …`
  for a client without DPoP) and `dpopProof` (`htm` = `method`, `htu` = the
  URI without query/fragment, `ath`, a fresh `jti`, the last nonce of that
  server). `toHeaders()` gives both. A proof is single use: authorize every
  request, retries included.
- `shouldRetryResourceRequest({required Uri uri, required int statusCode,
  String? dpopNonce, String? wwwAuthenticate})` → `bool`: report EVERY
  response. It caches a `DPoP-Nonce` header (also on successes) for the next
  proof to that origin, and answers `true` only for `401` +
  `WWW-Authenticate: DPoP error="use_dpop_nonce"` (RFC 9449 §9): retry that
  request once, never twice.
- Your API (and, for a browser app, its CORS policy) must accept the `DPoP`
  request header and expose `DPoP-Nonce` and `WWW-Authenticate`.
  LoginFlow's own `/v1/*` scopes already do.

### APIs, organizations and permissions

An application can have several independent APIs; each one is a resource
with its own audience and its own permissions (RFC 8707, RFC 9068). The
user has ONE session, and gets ONE access token per API, carrying only that
API's permissions in the active organization.

- Declare every API the app calls in `LoginFlowConfig.apis`, by audience.
  `accessTokenFor(api)` and `authorizedHeadersFor(api, …)` refuse any other
  with `ConfigurationInvalid`, before a request leaves the device.
- `accessTokenFor(String api)` → `Future<Result<String, LoginFlowError>>`:
  the first call for an API, and every call once its token is about to
  expire, refreshes the session with `resource=<api>` — same refresh
  family, same DPoP key, no new sign-in. Tokens are cached per API.
  Refreshes never overlap (each rotates the refresh token); concurrent
  callers for one API share one. `InvalidTarget(api)` means the server does
  not issue tokens for that API to this client (`invalid_target`); the
  session and the other APIs keep working.
- The organization is the product's unit of scope (a client company, a
  school). Every sign-in method but `signInWithAccessCode` takes
  `organization:` (an `Organization.id`) to start the session in it;
  without it the server activates the user's only organization, or none
  when there are several.
- `listOrganizations()` → `Future<Result<OrganizationList, LoginFlowError>>`:
  the organizations where the user has an active assignment
  (`id`, `name`, `kind` root/regular, `externalId`) and
  `activeOrganizationId`.
- `switchOrganization(String id)` → `Future<Result<void, LoginFlowError>>`:
  a refresh with `organization`. It drops every cached API token (they were
  issued for the previous organization) and empties
  `session.accessClaims`; the next `accessTokenFor` gets a token for the
  new one. `OrganizationUnavailable(id)` means the user has no assignment
  there; the session keeps its organization. A step-up keeps the active
  organization too.
- `session.accessClaims` (`Map<String, AccessTokenClaims>`, keyed by API):
  `organizationId`, `organizationExternalId`, `permissions` and
  `isPermissionsOverage` of each API token obtained so far; a new
  `SignedIn` is emitted when they change. **For the UI only**: they are
  decoded WITHOUT verifying the token. Show or hide parts of the interface
  with them; the API that verifies the token is the only authority on what
  the user may do. With `isPermissionsOverage` the token did not fit the
  permissions and only the API can resolve them.

```dart
final organizations = await auth.listOrganizations();
await auth.switchOrganization(organizations.data.organizations.first.id);
await auth.accessTokenFor('APP-ACME0RDERS');
final claims = (auth.state as SignedIn).session.accessClaims['APP-ACME0RDERS'];
final canCreateDrivers =
    claims?.permissions.contains('acme.drivers.create') ?? false; // UI only
```

Members (a generic "Team" screen, `doc/server-contract.md` §18): the
signed-in person manages who holds which role in an organization, decided by
LoginFlow's delegation rules — the UI never deduces power from roles.

- `listGrantableRoles(organizationId:)` → `GrantableRoles`: what a grant
  there would allow. Empty (`canGrant` false): hide the screen.
- `listMembers(organizationId:, query:, limit:, offset:)` → `MembersPage`:
  the people holding a role there, each `MemberAssignment` with
  `manageable` (offer "revoke" only when `true`).
- `inviteMember(organizationId:, email:, roleId:, …)` → `MemberInvitation`;
  `grantRole(…)` → `MemberAssignment`; `revokeAssignment(id)`.
- Refusals are `DelegationDenied(code: DelegationDenialCode.…)`; a write past
  the recent-sign-in window is `StepUpRequired` (call `stepUp`, then retry).

```dart
final roles = await auth.listGrantableRoles(organizationId: clientOrgId);
if (roles.data.canGrant) {
  await auth.inviteMember(
    organizationId: clientOrgId,
    email: 'admin@client.example',
    roleId: roles.data.roles.first.id,
  );
}
```

Changing the email (`doc/server-contract.md` §19): the signed-in person
changes their OWN address, in two steps. Same LoginFlow token as the members
calls; products keep no email-change route of their own.

- `startEmailChange(newEmail)` → `EmailChangeStarted`: a 6-digit code went to
  the new address and, when `confirmCurrent` (an account without a second
  factor), another to the current address. Codes live until `expiresAt`. The
  answer is the same when the new address cannot be used; then no code
  arrives.
- `confirmEmailChange(code, currentCode: …)` → `EmailChangeConfirmed`. The
  session is then refreshed: a new `SignedIn` carries the new email. Every
  other session of the person ends.
- Refusals: `StepUpRequired` on the start — `requirement.isStrongRequired`
  says whether a second factor is needed (an account with TOTP or a passkey)
  or only a recent sign-in; call `stepUp(requirement)`, finish its steps,
  then start again. `InvalidEmailAddress` (malformed, disposable, or the
  current email), `RateLimited(retryAfter)` (3 starts per hour), and
  `InvalidEmailChangeCode` for any refused confirmation — the server never
  says which code was wrong.

```dart
var started = await auth.startEmailChange('ana.new@example.com');
if (started case Err(error: StepUpRequired(:final requirement))) {
  await auth.stepUp(requirement); // answer its steps until SignedIn…
  started = await auth.startEmailChange('ana.new@example.com');
}
final confirmCurrent = started.data.confirmCurrent;
await auth.confirmEmailChange(
  newAddressCode,
  currentCode: confirmCurrent ? currentAddressCode : null,
);
```

Authenticator app (`doc/server-contract.md` §20): the signed-in person
turns TOTP on or off and gets recovery codes, with the session's own token.

- `totpStatus()` → `TotpStatus(isEnabled, verifiedAt)`.
- `startTotpEnrollment(issuer: …)` → `TotpEnrollment(secret, otpauthUri,
  issuer)`: show `otpauthUri` as a QR code and `secret` for typing it by
  hand. Nothing is on until `confirmTotpEnrollment(code)` succeeds.
- `disableTotp(code)` turns it off with a current code.
- `regenerateRecoveryCodes()` → a new set (every earlier code void); it
  needs a recent sign-in (`StepUpRequired`, then `stepUp` and ask again).
  Enabling issues none: ask right after.
- Refusals: `InvalidTotpCode` (a wrong code, or a locked account),
  `TotpAccountRefused(code)` (an access-code session).

```dart
final enrollment = await auth.startTotpEnrollment(issuer: 'Acme Console');
// show enrollment.data.otpauthUri as a QR code, then:
final confirmed = await auth.confirmTotpEnrollment(codeFromTheApp);
var codes = await auth.regenerateRecoveryCodes();
if (codes case Err(error: StepUpRequired(:final requirement))) {
  await auth.stepUp(requirement); // answer its steps until SignedIn…
  codes = await auth.regenerateRecoveryCodes();
}
```

Password change: `changePassword(newPassword)` sets or changes the signed-in
person's password in the app (`POST /v1/user/change-password`), with no
current password and no browser; an account without one gets its first.
It needs a recent sign-in, strong when the account has TOTP or a passkey
(`StepUpRequired`, then `stepUp` and ask again). `PasswordRejected(reason)`
is a weak, breached or unchanged password. Every other session of the
person ends; this one continues.

```dart
var changed = await auth.changePassword(newPassword);
if (changed case Err(error: StepUpRequired(:final requirement))) {
  await auth.stepUp(requirement); // answer its steps until SignedIn…
  changed = await auth.changePassword(newPassword);
}
```

Native SSO: when `initialize()` returns `SsoAvailable(candidate)`, show
"Continue as …" and call `continueWithSso()` or `declineSso()`. Call
`verifyDeviceSession()` when the app resumes so a device logout done by a
sibling app signs this one out too.

Logout: `auth.signOut(SignOutScope.app | device | browser | everywhere)`.

### Password reset (in-app)

Someone who forgot the password resets it inside the app, through the
library: an emailed code, the new password, then signed in. No browser,
no `redirectUri`; the app composes nothing but the screens.

- `startPasswordReset(email, {organization})` → `AwaitingResetCode(email)`:
  a code went to the address — or nothing did, when it has no account; the
  server answers the same either way, so say "if this email has an account,
  we sent it a code". `AlreadySignedIn` when someone is signed in (they use
  `changePassword`). The client's login methods must include `email_otp`.
- `submitResetCode(code)` → `AwaitingNewPassword(email)`. A refused code is
  `InvalidResetCode` (wrong, or any code for an unknown address) or
  `ResetCodeExpired` (expired or burned); the reset stays on the code.
  `resendResetCode()` asks for another: a request inside the server's
  interval between two codes is answered as sent, emails nothing, and the
  code already sent keeps working. An account with TOTP is asked for it
  first: a `ChallengeRequired` with `ChallengePurpose.passwordReset`,
  answered with `submitTotp` / `submitRecoveryCode`.
- `setNewPassword(newPassword)` → `SignedIn`, the session stored only now.
  The code's session is held until then: never stored, never a `SignedIn`,
  never shared through Native SSO, and `accessTokenFor` answers
  `NotSignedIn`; a restart in between signs nobody in. An account with a second factor
  (TOTP or a passkey) needs a strong sign-in to change it: the step-up
  opens by itself (`ChallengeRequired`, `ChallengePurpose.passwordReset`;
  answer it with `selectMethod(ChallengeStep.webauthnIdentify)` for a
  passkey, or the usual `submit*`), and the password is sent again when it
  completes. `PasswordRejected(reason)` (weak, breached or the current one)
  keeps `AwaitingNewPassword`: ask for another.
- `cancelPasswordReset()` → `SignedOut` from any step; a held session is
  signed out of this app (its refresh token revoked). `cancelChallenge()`
  on the step-up goes back to `AwaitingNewPassword`.
- `RateLimited(retryAfter)` and `NetworkFailure` keep the current step.

```dart
Future<void> runPasswordReset(LoginFlowAuth auth) async {
  await auth.startPasswordReset('ana@example.com'); // AwaitingResetCode
  final verified = await auth.submitResetCode(await askForCode());
  if (verified case Err(error: InvalidResetCode() || ResetCodeExpired())) {
    return; // show the error; offer auth.resendResetCode()
  }
  // A ChallengeRequired(purpose: passwordReset) first? Answer it, e.g.
  // auth.submitTotp(code), until AwaitingNewPassword.
  final saved = await auth.setNewPassword(await askForNewPassword());
  switch (saved) {
    case Ok(data: SignedIn()):
      break; // done: signed in with the new password
    case Ok(data: ChallengeRequired()):
      break; // the step-up: answer it, the password is then set by itself
    case Err(error: PasswordRejected()):
      break; // still AwaitingNewPassword: ask for another one
    case _:
      await auth.cancelPasswordReset(); // back to SignedOut
  }
}
```

The ready-to-use UI does all of this behind "Forgot your password?".

## Ready-to-use sign-in UI

### Configure once

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = LoginFlowPlatform.createAuth(
    config: LoginFlowConfig(
      issuer: LoginFlowEnvironment.production.issuer,
      clientId: 'acme-orders-mobile',
      redirectUri: Uri.parse('https://acme.example.com/oauth/callback'),
    ),
    // Passkeys are wired by default — nothing to pass for them. Google
    // needs the separate `loginflow_auth_google` package added above:
    googleIdTokenSource: const NativeGoogleIdTokenSource(),
  );
  await auth.initialize();

  LoginFlowSignInSetup.install(
    auth: auth,
    configuration: const SignInConfiguration(
      methods: [
        PasswordMethod(isForgotPasswordShown: true),
        EmailOtpMethod(resendCooldown: Duration(seconds: 30)),
        GoogleMethod(),
        MicrosoftMethod(),
      ],
      isSelfSignUpOffered: true,
      // `isPasskeySignInOffered` defaults to true: the server decides
      // whether a passkey is actually offered. Set it to false only to
      // hide a passkey the server allows, never to try to show one it
      // does not (see "What decides what is shown" below).
      isTemporaryAccessPassOffered: true,
      copy: SignInCopy(
        title: LocalizedText(english: 'Welcome to Acme', spanish: 'Bienvenido a Acme'),
      ),
    ),
  );

  runApp(AcmeApp(auth: auth));
}
```

### Show it

```dart
class AcmeApp extends StatelessWidget {
  const AcmeApp({required this.auth, super.key});

  final LoginFlowAuth auth;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF2B7A4B),
      extensions: const [
        LoginFlowSignInTheme(cardMaxWidth: 420, cornerRadius: 20),
      ],
    ),
    supportedLocales: const [Locale('en'), Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: LoginFlowSignIn(
      logo: Image.asset('assets/acme_logo.png'),
      onSignedIn: (session) => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      ),
    ),
  );
}
```

### What decides what is shown

- **Methods**: `SignInConfiguration.methods`, in that order, **intersected**
  with the methods the server enables for the client
  (`loginflow_login_options_endpoint`). A method the server does not allow is
  never shown; until the server answers, nothing unverified is shown. Google,
  Microsoft, Apple and Facebook only appear when the server's
  `login_methods` lists them — i.e. only when the company actually has that
  upstream provider configured and enabled. Apple's button follows the
  Apple Human Interface Guidelines (black, Apple's mark); Facebook's follows
  Meta's brand guidelines (Facebook blue) — both render their own branded
  widget instead of the generic outlined button the other methods share.
- **One method** → the UI opens it directly (password form or email form;
  Google/Microsoft/Apple/Facebook show their single button). Several → a
  method picker.
- **TOTP** → shown automatically whenever the server answers `next: totp`,
  with "use a recovery code" when the server offers it.
- **Sign-up** → "Create an account" only if `isSelfSignUpOffered` **and** the
  server enables self sign-up.
- **Forgot password** → only if `PasswordMethod.isForgotPasswordShown` **and**
  the server enables password reset **and** the client's login methods
  include `email_otp` (the reset is built on the email code). It runs the
  [in-app reset](#password-reset-in-app): the code, the new password typed
  twice, then signed in.
- **Passkey (first factor)** → "Continue with a passkey" on the method
  picker only if `isPasskeySignInOffered` (default `true`) **and** the
  server's company-wide passkey policy is `passwordless`
  (`ClientLoginOptions.isFirstFactorPasskeyOffered`). With the policy set to
  `mfa_only`, this button and `isPasskeyAutoSuggestOffered` both stay
  hidden — the server still prompts for a passkey automatically as a
  *second* factor mid-challenge, handled by `LoginFlowAuth` with no UI
  wiring needed. With the policy `disabled` (no `passkey` field), no
  passkey entry appears at all. The local flag can only hide what the
  server allows, never show what it does not.
- **Access code** → "I have an access code" on the method picker, the
  password and the email steps only if `isAccessCodeOffered` (default
  `false`) **and** the server lists `access_code` among the client's
  login methods (`ClientLoginOptions.isAccessCodeOffered`). It is never a
  method button of its own: the code is redeemed with
  `signInWithAccessCode`. The server still refuses codes when the
  application has them off (`AccessCodesUnavailable`). With no other
  method allowed, the access-code step is the entry screen itself. See
  [Access codes](#access-codes).
- **Native SSO** → "Continue as …" when a sibling app is signed in.
- **Errors** → a message above the step (wrong credentials, expired code,
  offline, …); **429** → "Too many attempts" with a countdown from
  `Retry-After`.

`AuthMethod` is a sealed class with the implemented methods only. Passkeys
and the Temporary Access Pass are implemented at the `LoginFlowAuth` API
level (`signInWithPasskey`, `submitTemporaryAccessPass`, see
[Passkeys](#passkeys-optional-adapter) below) but have no case in the
bundled picker widget yet; an app offering them builds its own button/screen
against `states`, the same way it would for any method not in this list.
When they are added here, every `switch` over `AuthMethod` fails to compile
until it handles them.

### Layout, theme, language, accessibility

- Screen class from the window's **shortest side**: mobile `< 600`,
  tablet `600–899`, desktop `≥ 900` (or width `≥ 1200`). Phones get a full
  screen; tablets and desktops a centered card. A phone in landscape stays
  mobile.
- Colors and typography come from your `ThemeData` (`ColorScheme`,
  `TextTheme`); spacing, radius, card width, logo height, button height and
  the loading bar thickness (1.5 px) come from `LoginFlowSignInTheme`.
- Texts in Spanish (base) and English, chosen from the effective locale; see
  [Language](#language) below. Provider buttons (Apple/Google/Microsoft/
  Facebook) always keep their mandatory brand colors and labels, regardless
  of your theme.
- Fields carry autofill hints (`email`, `password`, `oneTimeCode`), titles are
  semantic headers, messages are live regions, and every action is at least
  48 dp tall.

The UI uses `reactive_notifier` internally; your app does not have to.

### Language

Texts come from `.arb` files compiled with `flutter gen-l10n`
(`lib/src/sign_in/l10n/arb/login_flow_{es,en}.arb`), not hardcoded strings —
no widget ever branches on a locale itself. The effective locale, in order:

1. An explicit override set by your app with `LoginFlowLocaleService.setLocale(...)`.
2. The ambient `Localizations` locale of the widget tree.
3. `es` (the library's base locale), if neither of the above is supported.

```dart
// Force the built-in UI to English regardless of the device locale.
LoginFlowLocaleService.setLocale(const Locale('en'));

// Go back to following the device/ambient locale.
LoginFlowLocaleService.setLocale(null);
```

Setting an override reconstructs the mounted sign-in UI in place — no
navigation, no manual rebuild. Adding a language the library does not ship
yet is adding its `login_flow_<code>.arb` file under `lib/src/sign_in/l10n/
arb/` with every key from `login_flow_es.arb`, running `flutter gen-l10n`,
and listing it in `LoginFlowLocaleService.supportedLocales` — no widget
changes.

### Branding

Everything the built-in UI renders is driven by typed, host-supplied inputs
— never a hardcoded color, font or asset:

| What | Where it comes from |
|---|---|
| Colors (light/dark) | Your app's `ColorScheme` (`ThemeData.colorScheme` / `.copyWith(brightness: ...)`) |
| Typography | Your app's `TextTheme` |
| Logo | A `Widget?` you pass to the sign-in widget (`Image.asset`, `Image.network`, an `SvgPicture`, anything) |
| Spacing, corner radius, card width, logo height, button height, loading bar thickness | `LoginFlowSignInTheme` (a `ThemeExtension`) |
| Title / subtitle text | `SignInCopy` (per locale, via `LocalizedText`), usually set server-side through the client's `login-options` response |
| Provider button colors/labels | Fixed by each provider's brand guidelines — never themeable |

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: myBrandColor),
    extensions: const [
      LoginFlowSignInTheme(cardMaxWidth: 420, cornerRadius: 20),
    ],
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: myBrandColor,
      brightness: Brightness.dark,
    ),
    extensions: const [
      LoginFlowSignInTheme(cardMaxWidth: 420, cornerRadius: 20),
    ],
  ),
  home: LoginFlowSignIn(logo: Image.asset('assets/my_logo.png')),
);
```

`LoginFlowSignInTheme` is one extension shared by every screen of the flow;
there is no second, parallel branding object to keep in sync with it.

## Platform setup

### iOS

1. **Browser redirect**. Preferred: a claimed `https` redirect URI
   (Associated Domains `applinks:` + `apple-app-site-association`); it needs
   iOS 17.4+ for ASWebAuthenticationSession. On older iOS register a private
   reverse-domain scheme (`com.acme.orders:/oauth/callback`) instead
   (RFC 8252 §7.1). Nothing goes in `CFBundleURLTypes` for the browser
   callback: ASWebAuthenticationSession receives it directly.
2. **Secure storage**: nothing to configure for single-app use.
3. **Native SSO**: add *Keychain Sharing* in Xcode for every app of the
   publisher. Keep the app's **own group first** and add the shared one:

   ```xml
   <key>keychain-access-groups</key>
   <array>
     <string>$(AppIdentifierPrefix)com.acme.orders</string>
     <string>$(AppIdentifierPrefix)com.acme.loginflow.sso</string>
   </array>
   ```

   Pass the full group (`ABCDE12345.com.acme.loginflow.sso`) as
   `NativeSsoOptions.appleAccessGroup`. If the shared group were first, iOS
   would store private items there; the library detects it and refuses to
   write the session (`StorageFailure` with `MISCONFIGURED`). Items use
   `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and are never
   synchronized to iCloud.

### macOS

Same as iOS (the data-protection keychain is used so access groups apply).
In `DebugProfile.entitlements` and `Release.entitlements` add
`com.apple.security.network.client` and the `keychain-access-groups` above.

### Android

1. **Browser callback**: declare the callback activity with your redirect URI
   (an App Link is preferred, RFC 8252 §7.2):

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
                 android:host="acme.example.com"
                 android:path="/oauth/callback" />
       </intent-filter>
   </activity>
   ```

   Publish `/.well-known/assetlinks.json` for the host. Keep your
   `MainActivity` `launchMode="singleTop"` (the Flutter default).
2. **Secure storage**: values are AES-256-GCM encrypted with a non-exportable
   Android Keystore key. Exclude them from backups (a restored copy cannot be
   decrypted anyway and is discarded): in `data_extraction_rules.xml` /
   `full_backup_content.xml` exclude the shared preferences
   `dev.loginflow.auth.private.xml` and `dev.loginflow.auth.sso.xml`.
3. **Native SSO** (every app of the publisher, all signed with the same
   certificate):

   ```xml
   <permission
       android:name="com.acme.permission.LOGINFLOW_SSO"
       android:protectionLevel="signature" />
   <uses-permission android:name="com.acme.permission.LOGINFLOW_SSO" />

   <queries>
       <!-- one entry per sibling app -->
       <provider android:authorities="com.acme.admin.loginflow.sso" />
   </queries>

   <application>
       <provider
           android:name="dev.loginflow.auth.sso.LoginFlowSsoProvider"
           android:authorities="${applicationId}.loginflow.sso"
           android:exported="true"
           android:readPermission="com.acme.permission.LOGINFLOW_SSO"
           android:writePermission="com.acme.permission.LOGINFLOW_SSO" />
   </application>
   ```

   List the siblings' authorities in
   `NativeSsoOptions.androidSiblingAuthorities`. Besides the signature
   permission, the provider checks the caller's certificate, and the library
   only talks to a sibling whose package is signed with the same certificate.
   `sharedUserId` and Block Store are not used (`doc/decisions.md` D12).

### Magic link (Android App Links / iOS Universal Links)

Each OAuth client (app) has its OWN magic-link path,
`/login/magic/<client_id>`, on the company's login host — a company that
runs several apps on the same host must give each app its own intent
filter / Associated Domains entry for its own `client_id`, never one
shared entry (`docs/operations/passkeys.md` §4 on the server). Set this up
once per app; the library does the rest (`LoginFlowAuth.
magicLinkTokenFromUri`, `SignInViewModel.sendMagicLink`/the "email me a
sign-in link instead" button, shown only when the server publishes
`magic_link` in `login-options`).

- **Android**, `AndroidManifest.xml` (same `autoVerify` App Link pattern as
  the browser callback above, but scoped to this app's own path):

  ```xml
  <intent-filter android:autoVerify="true">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="https"
            android:host="acme.id.loginflow.dev"
            android:pathPrefix="/login/magic/app-one" />
  </intent-filter>
  ```

  Deliver the intercepted link to Flutter with a deep-link plugin (e.g.
  `app_links`) and extract the token:

  ```dart
  AppLinks().uriLinkStream.listen((uri) {
    final token = auth.magicLinkTokenFromUri(uri);
    if (token != null) {
      unawaited(auth.submitMagicLinkToken(token));
    }
  });
  ```

- **iOS**: Associated Domains capability, `applinks:acme.id.loginflow.dev`
  — the entitlement is per HOST, shared by every app of the company on
  that host (the AASA's own `applinks.details[].components` is what scopes
  each app's `appID` to only its own `/login/magic/<client_id>` path, so
  two apps with the same entitlement still only ever match their own
  link). Handle the Universal Link the same way, through
  `UIApplicationDelegate.application(_:continue:restorationHandler:)` (or
  the SwiftUI `onOpenURL`) forwarded to the same `magicLinkTokenFromUri` /
  `submitMagicLinkToken` call above.
- `submitMagicLinkToken` continues the attempt the SAME browser/app
  session already has open (the one that called `requestMagicLink` or
  `requestEmailOtp`) — opening the link in a context with no attempt in
  progress answers `invalid_session`, by design (contract: magic link,
  prevents login CSRF and session fixation).

### Web

The web runs the **same native sign-in** as the apps (password, email code,
passkeys, TOTP, recovery codes, Temporary Access Pass, and
Google/Microsoft/Apple through the hosted page), with the session bound to a
non-extractable DPoP key so it survives reloads. `signInWithBrowser` (the
authorization-code redirect) remains available.

**Server configuration** (once per app):

1. The OAuth client is **first-party** and lists the app's exact origins:
   `PATCH /v1/control/oauth-clients/{client_id}/web-origins` with
   `{"allowed_web_origins": ["https://app.acme.com"]}` (`https://host[:port]`;
   `http://localhost` only in a development `APP_ENV`). This opens CORS on
   `POST /oauth2/authorize-challenge` for those origins only, makes DPoP
   mandatory for the client (`doc/server-contract.md` §5.1, §13), and lists
   the origins in the company RP host's `/.well-known/webauthn` (passkeys).
2. The same origins are in the server's `CORS_ALLOWED_ORIGINS`: discovery,
   JWKS, login options, token, revocation and the `/v1/*` scopes (the passkey
   account API) are called from JavaScript.
3. A registered `https` redirect URI on the app's origin for the browser
   steps (Microsoft, sign-up, Google/Apple without a native source).

**App configuration**:

```dart
final auth = LoginFlowPlatform.createAuth(
  config: LoginFlowConfig(
    issuer: LoginFlowEnvironment.production.issuer,
    clientId: 'acme-orders-web',
    redirectUri: Uri.parse('https://app.acme.com/oauth/callback'),
    enableDpop: true, // mandatory for clients with allowed_web_origins
  ),
);
// Restores the stored session (refreshing it with the same key) and
// completes a browser-step callback when the page is one.
final started = await auth.initialize(launchUri: Uri.base);
```

- **Persistence.** With `enableDpop: true` the refresh token, ID token and
  session metadata live in `localStorage`; the ES256 private key is a
  non-extractable WebCrypto `CryptoKey` in IndexedDB that JavaScript (this
  library included) can use but never read. A copied refresh token is
  useless without that key. `initialize()` checks the stored session's key
  thumbprint (`cnf.jkt`) against the browser's key and refreshes with it:
  a missing key (cleared site data, private browsing) or a refused refresh
  (`invalid_grant`, e.g. the 24 h absolute lifetime of web refresh tokens)
  ends the session locally with `SignedOut(reason: sessionRevoked)`. Without
  DPoP, tokens stay in memory only and a reload loses them.
- **Tabs** share the stored session; before refreshing, each one adopts a
  refresh token another tab already rotated, so the server never sees an
  old token presented again (which would revoke the whole family).
- **Browser steps** are a top-level redirect: the PKCE verifier, `state` and
  `nonce` survive it in `sessionStorage`, are deleted as soon as the matching
  callback is consumed, expire after 10 minutes, and the callback parameters
  are removed from the address bar.
- **Passkeys** run through the browser's WebAuthn API (`passkeys_web`)
  against the company's RP ID; the app's origin is a *related origin*
  (WebAuthn L3 Related Origin Requests), so a browser without that feature
  refuses the ceremony. `passkeys_web` needs Corbado's `bundle.js` in
  `web/index.html` **before** `flutter_bootstrap.js` — without it the plugin
  closes the window at start-up:

  ```html
  <script src="https://github.com/corbado/flutter-passkeys/releases/download/2.4.0/bundle.js"></script>
  ```

  Self-host the file with an integrity hash in production.
- **Magic link**: see [Limitations](#limitations).
- SSO across dashboard domains still comes from the LoginFlow session cookie
  on the authorization server's own domain for the browser steps (top-level
  navigation, no iframes, no third-party cookies).

### Linux

The native sign-in, its challenge methods and the browser steps work as on
the other desktops:

- **Secure storage**: the session (and the DPoP key) live in the user's
  Secret Service keyring (GNOME Keyring, KWallet) through libsecret, via the
  `flutter_secure_storage_linux` plugin. Building needs the libsecret
  development package (`libsecret-1-dev` on Debian/Ubuntu); at runtime a
  Secret Service must be running and unlocked, otherwise storage reports
  `StorageFailure`.
- **Browser steps** (`redirect_to_web`: Microsoft, sign-up, Google/Apple)
  open the default browser (`xdg-open`) and wait on an
  RFC 8252 §7.3 loopback redirect. Register a **native** client with a
  fixed-port loopback redirect URI and use exactly that URI:
  `redirectUri: Uri.parse('http://127.0.0.1:53682/oauth/callback')`.
  LoginFlow compares redirect URIs exactly (port included), so ephemeral
  ports are not supported; if the port is taken, the step fails as
  `BrowserFailed(failed)`.
- **DPoP**: Linux has no OS API for a non-exportable key, so the ES256 key
  is a software key generated with the platform CSPRNG and kept in the same
  keyring as the session. Tokens are still bound to it, but it is weaker
  than the hardware-backed keys of the other platforms.
- **Passkeys are not available**: there is no OS WebAuthn API a Flutter app
  can call. Passkey sign-in and enrollment fail with
  `PasskeyFailed(reason: notSupported)` (shown by the sign-in UI as an
  unsupported device), never a crash; offer the other methods on Linux.
- Native SSO does not apply.

### Google

Add the `loginflow_auth_google` package (above) and pass
[`NativeGoogleIdTokenSource`](packages/loginflow_auth_google/lib/src/native_google_id_token_source.dart)
to `googleIdTokenSource` — its own native plugin (Credential Manager on
Android via `GetSignInWithGoogleOption`, `GIDSignIn` on iOS), requesting
the ID token for `prompt.clientId` (the company's Google *web* client, from
the `upstream_token` challenge step, `doc/server-contract.md` §5.3/§5.6)
with `prompt.nonce` passed straight through as the per-attempt nonce — a
real possession proof the server can check, not a one-shot SDK
initialization worked around after the fact.

- **Android**: create an *Android* OAuth client (package + SHA-1) and a
  *Web* client in the company's Google Cloud project. No manifest change.
- **iOS/macOS**: create an *iOS* OAuth client; add `GIDClientID` to
  `Info.plist` (or pass `NativeGoogleIdTokenSource(iosClientId: …)`) and
  the reversed client ID as a URL scheme in `CFBundleURLTypes`.
- Without the package, Google runs in the system browser through
  LoginFlow's hosted page (`signInWithGoogle`'s existing fallback).

### Apple

Add the `loginflow_auth_apple` package (above) and pass
[`NativeAppleTokenSource`](packages/loginflow_auth_apple/lib/src/native_apple_token_source.dart)
to `appleTokenSource` — `AuthenticationServices` via the `sign_in_with_apple`
pub package, requesting the ID token with `prompt.nonce` as the raw nonce
(the package hashes it with SHA-256 before handing it to Apple's native
API; Apple's `identityToken` carries the raw value back in its `nonce`
claim for the server to compare, `doc/server-contract.md` §5.4).

- Add the **Sign in with Apple** capability to the app target in Xcode
  (Signing & Capabilities).
- The company's Services ID (or the app's bundle ID) must match LoginFlow's
  Apple provider configuration for this client.
- `NativeAppleTokenSource.isAvailable` is `false` on every platform other
  than iOS/macOS — in particular Android, where
  `sign_in_with_apple`'s own web-based flow is deliberately not used.
  Without the package, or on a platform the source reports unavailable,
  Apple runs in the system browser through LoginFlow's hosted page, the
  same fallback Google has without `loginflow_auth_google`.
- On the first authorization only, Apple returns the user's given/family
  name; the library forwards it to the server as `upstream_user_name`
  without the app having to cache it.

### Facebook

Add the `loginflow_auth_facebook` package (above) and pass
[`NativeFacebookTokenSource`](packages/loginflow_auth_facebook/lib/src/native_facebook_token_source.dart)
to `facebookTokenSource` — the `flutter_facebook_auth` pub package: Limited
Login on iOS (an OIDC ID token with `prompt.nonce`) and classic login on
Android (a nonceless access token). The source picks the right one per
platform and reports the resulting shape to the server as
`upstream_token_type` (`id_token` or `access_token`,
`doc/server-contract.md` §5.4) — the app never branches on platform itself.

- Create the app in Meta for Developers and add the Facebook Login product.
- **Android**: `facebook_app_id` / `facebook_client_token` /
  `fb_login_protocol_scheme` string resources plus the matching manifest
  entries (see the package README).
- **iOS**: `FacebookAppID` / `FacebookClientToken` / `FacebookDisplayName`
  in `Info.plist`, the `fbYOUR_APP_ID` URL scheme, and
  `LSApplicationQueriesSchemes` for `fbapi`/`fb-messenger-share-api`.
- Without the package, Facebook runs in the system browser through
  LoginFlow's hosted page.

### Passkeys

`LoginFlowPlatform.createAuth` wires
[`CorbadoPasskeyAuthenticator`](lib/src/platform/webauthn/corbado_passkey_authenticator.dart)
(the `passkeys` pub package by Corbado: Android Credential Manager,
iOS/macOS AuthenticationServices, the browser's WebAuthn API) by default —
nothing to pass for passkeys to work, on every platform that package
supports. Pass `enablePasskeys: false` to turn it off, or
`passkeyAuthenticator: myOwnAuthenticator` to replace it (e.g. a test
double — `PasskeyAuthenticator`, `loginflow_auth_core.dart`, is still a
plain interface for that purpose).

Every company has its own **relying party (RP) ID**: a fixed,
per-company host of the shape `<slug>.id.loginflow.dev` (LoginFlow's
multi-tenant hosted domain) — never the app's own domain, and never
changed once passkeys are enrolled (an RP ID change invalidates every
existing passkey). `doc/server-contract.md` §5.7 and §15 cover the wire;
the platform association below is what makes the OS trust that host for
*your* app specifically.

- **iOS/macOS**: add the **Associated Domains** capability in Xcode with a
  `webcredentials:<slug>.id.loginflow.dev` entry (one entry per company the
  app can sign a user into — most apps have exactly one):

  ```
  webcredentials:acme.id.loginflow.dev
  ```

  This is the LoginFlow domain's `apple-app-site-association` (served from
  `https://<slug>.id.loginflow.dev/.well-known/apple-app-site-association`,
  §15) that must list your app's Team ID + bundle identifier — ask the
  company admin to register it via the master API
  (`PATCH /v1/control/companies/{company_id}/oauth-clients/{client_id}/passkey-app-registration`,
  `doc/server-contract.md` §15), the same way an Associated Domain is
  verified for a universal link, except the file lives on LoginFlow's host,
  not the app's own.
- **Android**: no manifest entry for the RP ID itself — WebAuthn credential
  requests already carry the RP ID, and Android resolves it against that
  domain's own `/.well-known/assetlinks.json`
  (`https://<slug>.id.loginflow.dev/.well-known/assetlinks.json`, §15),
  which the same master endpoint above publishes with your app's package
  name and signing certificate SHA-256. Register the SHA-256 of the
  certificate you release with (the Play App Signing certificate in
  production, not your local debug key) with the company admin.
- **Web**: `passkeys_web` runs `navigator.credentials` with the company's
  RP ID from a registered origin (a related origin, listed by the server
  in `https://<rp_id>/.well-known/webauthn`); see [Web](#web) for the
  required `bundle.js` and the server configuration.
- **Linux**: no passkeys (see [Linux](#linux)).

Platform requirements, in short: Android 9 (API 28)+ with Google Play
services and a signed-in Google account; iOS 16+/macOS 13.5+ with the
Associated Domain above; on the web, a browser with WebAuthn and Corbado's
`bundle.js`. On Android the platform signs the ceremony with your app's
own origin (`android:apk-key-hash:<base64url SHA-256 of the signing
certificate>`), not an `https://` origin — the server must know that
certificate (the same SHA-256 registered for `assetlinks.json`).

#### Ceremony behaviour and failures

Every ceremony `CorbadoPasskeyAuthenticator` runs is **modal**: the
platform's passkey sheet or dialog. The server sends `mediation:
"conditional"` for a discoverable request (no `login_hint`); the adapter
never forwards it, because a conditional request only resolves from a
focused autofill field and, without one, waits forever on iOS and the
web. Each ceremony is bounded by `ceremonyTimeout` (default
`CorbadoPasskeyAuthenticator.defaultCeremonyTimeout`, 120 s); the stuck
sheet is cancelled when it expires.

A ceremony never throws. Every failure — of the plugin, the platform or
the JSON — is `PasskeyFailed`, with a `reason` to switch over and the
platform's original `code`/`description` for logs:

| `PasskeyFailureReason` | Cause (platform code) |
|---|---|
| `notConfigured` | No `PasskeyAuthenticator` configured |
| `userCancelled` | Sheet dismissed or ceremony aborted (`NotAllowedError`, `AbortError`, `cancelled`) |
| `noCredentialsAvailable` | No passkey for this RP on the device |
| `notSupported` | Device, OS or account cannot use passkeys (`NotSupportedError`, no Google account on Android, Linux) |
| `securityError` | RP ID not valid for the caller (`SecurityError`) — usually the RP ID's domain does not list this app or origin |
| `domainNotAssociated` | Associated Domain / `assetlinks.json` missing for this app (`domain-not-associated`) |
| `alreadyRegistered` | Enrollment: this authenticator already holds a passkey for the account (`InvalidStateError`) |
| `timeout` | No result within `ceremonyTimeout`, or the platform's own timeout |
| `invalidResponse` | Options or response not of the expected JSON shape |
| `unknown` | Anything else; read `code`/`description` |

The bundled sign-in UI shows no message for `userCancelled`, the
"unavailable" message for `notConfigured`, `notSupported`,
`noCredentialsAvailable`, `securityError` and `domainNotAssociated`, and
the generic error for the rest — and its busy state always ends, whatever
the ceremony does.

A ceremony that succeeded can still be refused by the server: a
credential it no longer knows (deleted after a new access code, a
revocation or by the user), or a company policy, client or sign-in gate
that refuses it. That ends the sign-in with `PasskeyRejected` — the
ceremony is never run again on that attempt — and the bundled UI shows the
"invalid credentials" message.

#### Managing enrolled passkeys: `LoginFlowPasskeys`

`LoginFlowPasskeys` is the ready-to-use manager for the signed-in user: it
lists their passkeys (name, when added, when last used) and adds, renames
and deletes them — delete behind a confirmation. It works with the client
installed by `LoginFlowSignInSetup.install`, uses the same
`LoginFlowSignInTheme`, languages and mobile/tablet/desktop layouts as the
sign-in UI, and is shown as a route:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => const LoginFlowPasskeys()),
);
```

The platform's passkey sheet shows the account as `username` and
`displayName`; by default they come from the session identity: for a
person, the email (else the subject); for an access-code subject, its
display name (else its external id), the server's own default; the
display name falls back to the username. Pass them to override:

```dart
const LoginFlowPasskeys(username: 'ana@example.com', displayName: 'Ana Ruiz')
```

Adding a passkey goes through the server's recent-authentication gate (see
below). When the server answers `StepUpRequired`, the manager calls
`stepUp` with the server's requirement and shows the step it asks for
(password, TOTP, …) with the sign-in UI's own screens, inside the manager;
the password step also offers "Email me a code" when the client's login
options list `email_otp` (or the prompt's `methods` do), so an account
that only signs in with email codes is never stuck on a password. Once
the user signs in again, the passkey is added — retried once, never in a
loop. "Cancel" (or the step's "Back") abandons it. A failed ceremony
shows its real `PasskeyFailed` reason (see the table above), a dismissed
sheet shows nothing, and the manager is never left busy. Every signed-in
principal gets "Add a passkey", an access-code `person` or `device`
subject included. A passkey path the server cannot serve (passkeys off
for the company, `passkey` not among the client's login methods) answers
a coded `403`: `PasskeyAccountRefused(code)` from the API, "Passkeys are
not available for this account" in the manager.

#### Managing enrolled passkeys: the API

To build your own screen instead, use the API directly:

```dart
class PasskeysScreen extends StatelessWidget {
  const PasskeysScreen({required this.auth, super.key});

  final LoginFlowAuth auth;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: auth.listPasskeys(),
    builder: (context, snapshot) {
      final result = snapshot.data;
      if (result == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return result.when(
        ok: (passkeys) => ListView(
          children: [
            for (final passkey in passkeys)
              ListTile(
                title: Text(passkey.name ?? passkey.id),
                subtitle: Text('Added ${passkey.createdAt}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => auth.deletePasskey(passkey.id),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add a passkey'),
              onTap: () => auth.enrollPasskey(
                username: 'ana@example.com', // the signed-in user's email
                displayName: 'Ana Ruiz',
              ),
            ),
          ],
        ),
        err: (error) => Text(error.message),
      );
    },
  );
}
```

`enrollPasskey` goes through the RFC 9470 recently-authenticated gate the
server enforces on `enroll/*` (`doc/server-contract.md` §15): with a
sign-in older than 300 s it fails with `StepUpRequired`, whose
`requirement` (`max_age`, `acr_values`) comes from the server's
`WWW-Authenticate` challenge. Re-authenticate with it, then retry:

```dart
Future<Result<PasskeyCredential, LoginFlowError>> enroll(
  LoginFlowAuth auth,
) async {
  final enrolled = await auth.enrollPasskey(
    username: 'ana@example.com',
    displayName: 'Ana Ruiz',
  );
  if (enrolled case Err(error: StepUpRequired(:final requirement))) {
    // Drive the resulting ChallengeRequired state (password, TOTP, ...)
    // to SignedIn, then call enrollPasskey again.
    await auth.stepUp(requirement);
  }
  return enrolled;
}
```

### Access codes

For people and devices that live in **your** backend, not in LoginFlow —
a driver or recorder, a student, a referee, a kiosk — your backend issues
a single-use code (`POST /v1/service/access-codes` with a confidential
client holding `loginflow.accessCodes.issue`) and hands it out; the person or
device types it in the app:

1. Your backend issues the code for its own subject id (`external_subject`),
   with a `subject_kind` (`person` or `device`) and a `profile` (`Driver`,
   `Kiosk`, ...). The code (`XXXX-XXXX`) comes back once.
2. The app calls `signInWithAccessCode(code)`. It runs the native challenge
   (`method=access_code`) with a DPoP proof, so the session is bound to
   this device's key, and returns the same
   `Result<AuthState, LoginFlowError>` as the other sign-in methods.
3. The identity of the session carries `externalSubject` (your id — key
   your data on it), `subjectKind` and `subjectProfile` (the `ext_sub`,
   `subject_kind` and `ext_profile` claims; the label is never the standard
   OIDC `profile` claim, a profile-page URL); all three are `null` for a
   regular user. LoginFlow stores no personal data for these subjects.

DPoP is required: set `enableDpop: true` in `LoginFlowConfig` (it is off by
default; `LoginFlowPlatform.createAuth` then wires the platform key store).
Without it `signInWithAccessCode` fails with `ConfigurationInvalid` before
any request. The other failures are typed:

| Error | When |
|---|---|
| `InvalidAccessCode` | malformed (refused locally), or `400 invalid_grant`: unknown, expired, already used or revoked — never told apart |
| `AccessCodeThrottled(retryAfter)` | `429 slow_down` + `Retry-After` (seconds): too many failures from this device or address, or for the whole application |
| `AccessCodesUnavailable` | `400 access_codes_disabled` for the application, or a server that answers the method with a step |
| `UnsupportedByServer` | the discovery document has no `authorization_challenge_endpoint` |
| `OAuthProtocolError` | any other refusal: `unauthorized_client` (the client's login methods lack `access_code`), `invalid_dpop_proof`, `invalid_scope`, `invalid_request`, `temporarily_unavailable` |

`access_code` is a login method of the OAuth client, like `password` or
`passkey`: turn it on for the app's client (panel: client → Login methods →
Access code) **and** enable access codes on the application (TTL, subject
kinds). The login options then list it (`ClientLoginOptions.isAccessCodeOffered`).

**With the bundled UI** there is nothing to write: set
`SignInConfiguration.isAccessCodeOffered: true` (and `enableDpop`).
While the client lists `access_code`, `LoginFlowSignIn` offers "I have an access code" (or opens on the
code step when the app has no other method), formats the field, refuses
an incomplete code locally — no request, no failed attempt counted —,
redeems it, and maps every failure to its own message:
`InvalidAccessCode` → "That access code is not valid…",
`AccessCodesUnavailable` (and `UnsupportedByServer`) → "Access codes are
not available for this app", `ConfigurationInvalid` (no DPoP) → "This
app is not set up to sign in with access codes", `AccessCodeThrottled` →
the "Too many attempts" countdown from `retryAfter`, a network failure →
the offline message. The step is never left busy.

```dart
// A kiosk or driver app whose only way in is an access code.
final auth = LoginFlowPlatform.createAuth(
  config: LoginFlowConfig(
    issuer: LoginFlowEnvironment.production.issuer,
    clientId: 'routes-driver-app',
    enableDpop: true,
  ),
);
LoginFlowSignInSetup.install(
  auth: auth,
  configuration: const SignInConfiguration(
    methods: [],
    isAccessCodeOffered: true,
  ),
);
```

**Your own screen**: every app shares one definition of the code:
`AccessCodeFormat` (`alphabet`, `length`, `normalize`, `isComplete`,
`display`) and the
`AccessCodeInputFormatter` for the text field, which uppercases, drops
characters outside the alphabet and inserts the dash:

```dart
TextField(
  inputFormatters: const [AccessCodeInputFormatter()],
  textCapitalization: TextCapitalization.characters,
  autocorrect: false,
  enableSuggestions: false,
  onSubmitted: viewModel.redeemAccessCode, // calls auth.signInWithAccessCode
)
```

Enable the submit button with `AccessCodeFormat.isComplete(text)`.

**Code once, then passkey.** After redeeming, the subject — a `person` or
a `device` — may enroll a passkey, so its next sign-in needs no code. The
client lists both `access_code` and `passkey`:

1. Right after `signInWithAccessCode`, within the server's 300 s
   recent-authentication window, call `enrollPasskey` (or show
   `LoginFlowPasskeys`). A phone that cannot do passkeys
   (`PasskeyFailed(notSupported)`, the user dismissed the sheet) keeps
   working on the code session.
2. When the session has ended (`SignedOut`, `SessionRevoked`), call
   `signInWithPasskey()` with no arguments: the credential itself names the
   subject, and the session is the same subject (`externalSubject`,
   `subjectKind`, `subjectProfile`), DPoP-bound, as the code gave.
3. If that fails — no passkey on the phone
   (`PasskeyFailed(noCredentialsAvailable)`), or `PasskeyRejected` because
   the backend issued a new code, revoked or deleted the subject, which
   deletes its passkeys — fall back to asking for a code.

The full recipe is in [`doc/integration-guide.md`](doc/integration-guide.md#41-code-once-then-passkey-device-and-person-apps).

Why it is safe to hand out (OWASP ASVS V2/V3, NIST SP 800-63B look-up and
out-of-band secrets): codes are random (CSPRNG) from an alphabet without
look-alikes, **single use** (the row is deleted on redeem), short-lived
(7 hours to 5 days, set per issue), stored only as a keyed hash (HMAC with
a server pepper), and one active code exists per subject. Redemption is
rate-limited per address and per DPoP key, plus a per-application failure
threshold that throttles the whole application and raises an alert in the
panel; every failure answers the same generic error, so a response never
tells which codes exist. The session is bound to the device's DPoP key, so
a stolen refresh token is useless elsewhere. Wire details:
`doc/server-contract.md` §16.

## Security notes

- PKCE S256 on every authorization; `plain` is never sent.
- `state` and `iss` (RFC 9207) are checked before a code is redeemed.
- Refresh tokens rotate on every use; a rejected refresh clears the session.
- Refresh tokens are never shared between apps; Native SSO shares only the
  device secret and the ID token bound to it.
- Tokens, secrets and codes are never logged (`toString` of models that hold
  them is redacted).
- On the web a session is persisted only when it is DPoP-bound, and never
  the private key material: the key is a non-extractable WebCrypto key.

## Limitations

- Windows: no secure storage, system browser or DPoP key implementation; the
  session lives in memory and browser steps fail as unavailable. Without a
  DPoP key, a native first-party client (which the server requires to use
  DPoP) cannot sign in on Windows, and `signInWithAccessCode` fails with
  `ConfigurationInvalid`.
- Linux: no passkeys; the DPoP key is a software key in the keyring (see
  [Linux](#linux)); the loopback redirect needs a fixed, registered port.
- Web, magic link: the emailed link opens `https://<company host>/login/magic/<client_id>`
  in a new tab, not in the tab whose attempt requested it, and that attempt
  (its `auth_session`) lives only in the requesting tab's memory, so the
  library cannot continue it from the link; use the code from the same
  email on the web.
- Web, tabs: two tabs refreshing at the very same moment can still present
  one refresh token twice (there is no cross-tab lock); the server then
  revokes the family and both tabs sign out.
- Google and Microsoft buttons have no brand marks; add them per each
  provider's branding guidelines.
- Passkeys: no conditional UI/autofill on any platform (the
  `mediation: "conditional"` request tied to a username field) — every
  ceremony, the bundled passkey button and auto-suggest included, is a
  full, visible, modal one (see [Ceremony behaviour and
  failures](#ceremony-behaviour-and-failures)). True autofill needs a
  platform-specific hook this library does not expose.
- Access-code subjects and passkeys: the server deletes every passkey of
  a subject when its backend issues a new code with
  `revoke_existing_sessions`, revokes or deletes the subject. The phone's
  credential then stays on the device but no longer signs in
  (`signInWithPasskey` fails with `PasskeyRejected`), so an app must keep
  the code as the way
  back in. A synced passkey used on another phone signs in with that
  phone's DPoP key: a backend that binds a subject to one device sees a
  different key.
- The bundled passkey manager (`LoginFlowPasskeys`) and the
  re-authentication it asks for need the sign-in UI installed
  (`LoginFlowSignInSetup.install`). A `LoginFlowSignIn` still mounted under
  it (not replaced after sign-in) completes again when that
  re-authentication does and calls its `onSignedIn` once more.

## Manual test plan

The Dart layer and the pure Kotlin decisions are covered by automated tests.
These checks need a device, a browser or a Linux desktop and are not
automated:

| # | Platform | Steps | Expected |
|---|---|---|---|
| 1 | Android | Sign in with Microsoft | Custom Tab opens; after login the app is in front and signed in |
| 2 | Android | Start Microsoft, close the tab | `BrowserFailed(cancelled)`, back to the method picker |
| 3 | Android | Sign in, kill the app, reopen | Still signed in (Keystore-encrypted session) |
| 4 | Android | Two apps signed with the same certificate, sign in on A, open B | B shows "Continue as …" and signs in |
| 5 | Android | App from another certificate declares B's authority | A never sends it the SSO entry |
| 6 | Android | Device logout on A, resume B | B is signed out |
| 7 | iOS | Steps 1–4 and 6 with ASWebAuthenticationSession and the shared keychain group | Same results |
| 8 | iOS | Put the shared group first in `keychain-access-groups` | Sign-in fails with `StorageFailure` (`MISCONFIGURED`) |
| 9 | Android, iOS | Google (`signInWithGoogle` / the picker's Google button) | Account sheet (Credential Manager / `GIDSignIn`), then signed in |
| 10 | Android | While the Custom Tab is open, fire `adb shell am start -a android.intent.action.VIEW -d "<redirect URI>?code=x&state=forged"` | Nothing happens; the tab stays open and finishing the login still signs in |
| 11 | Android | Sign in, change the screen lock (invalidates Keystore keys), sign in again | The stored session is discarded once; the new sign-in persists normally |
| 12 | Android | Tap "Continue with a passkey" with an enrolled passkey on the device | Credential Manager bottom sheet, then signed in |
| 13 | iOS/macOS | Tap "Continue with a passkey" with an enrolled passkey in iCloud Keychain | AuthenticationServices sheet, then signed in |
| 14 | Android/iOS | Enroll a passkey (`enrollPasskey`) without a recent sign-in | `StepUpRequired` with `max_age` 300 s; after `stepUp`, the retry enrolls |
| 15 | Android/iOS | "Use a temporary access pass" with a code issued by a company admin | Signs in directly, no TOTP step even on an account with TOTP enabled |
| 16 | Web | From a registered origin, sign in with password + TOTP, reload the page | Still signed in; the session is in `localStorage`, the key is a non-extractable `CryptoKey` in IndexedDB |
| 17 | Web | Signed in, delete the site's IndexedDB only, reload | `SignedOut(reason: sessionRevoked)`, the stored session is removed |
| 18 | Web | "Continue with a passkey" from the app origin | Browser passkey sheet for the company RP ID, then signed in |
| 19 | Web | The same app served from an origin NOT in `allowed_web_origins` | Sign-in fails (CORS refused / `unauthorized_client`) |
| 20 | Linux | Sign in, quit, reopen | Still signed in (Secret Service) |
| 21 | Linux | Microsoft / sign-up | Default browser opens; after login the app is signed in and the tab says it can be closed |
| 22 | Linux | "Continue with a passkey" | The "not supported" message, no crash |
| 23 | iOS, Web | "Continue with a passkey" with no remembered email (discoverable request) | A modal passkey sheet opens at once; dismissing it returns to the picker with no spinner |
| 24 | Android | Enroll a passkey twice on the same device | `PasskeyFailed(alreadyRegistered)` |
| 25 | Android | App signed with a certificate the company did not register | `PasskeyFailed(securityError)` or `domainNotAssociated`, the picker stays usable |
| 26 | Android, iOS, Web | "Forgot your password?" with a real mailbox: type the emailed code, then a new password twice | No browser opens; signed in only after "Save password"; the new password signs in on another device |
| 27 | Android, iOS | Same as 26 on an account with a passkey and no TOTP | After the code, "Save password" asks for the passkey; once confirmed, signed in with the new password |

## Development

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
TZ=UTC flutter test                      # VM tests
TZ=UTC flutter test --platform chrome test/web
(cd packages/loginflow_auth_google && flutter test)
# JVM unit tests of the Android plugin (from an app that depends on it):
./gradlew :loginflow_auth:testDebugUnitTest
```

The tests run against a fake LoginFlow server (`test/support/`) that
implements `doc/server-contract.md` over a loopback `HttpServer` (core tests)
or an in-memory `MockClient` (widget tests).
