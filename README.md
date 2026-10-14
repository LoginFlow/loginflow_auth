# loginflow_auth

Flutter client library for **LoginFlow**, the OAuth 2.0 / OpenID Connect
provider. It gives first-party apps:

- **Native sign-in** (password, email one-time code, TOTP step-up, Google)
  through the OAuth 2.0 *Authorization Challenge Endpoint*
  (draft-ietf-oauth-first-party-apps-04), ending in an authorization code
  redeemed with PKCE S256.
- **System-browser fallback** (ASWebAuthenticationSession, Custom Tabs, a
  top-level redirect on the web) whenever the server answers
  `redirect_to_web`: Microsoft, sign-up, password reset. Never a WebView.
- **ID token validation** (signature through the issuer JWKS, `iss`, `aud`,
  `azp`, `nonce`, `exp`, `iat`) before any claim is trusted.
- **Token lifecycle**: in-memory access tokens, refresh with rotation,
  single-flight refresh, and a rejected refresh treated as a logout.
- **Native SSO** (OpenID Connect Native SSO, draft 07) between apps of the
  same publisher: a shared `device_secret` + ID token, exchanged by each app
  for its own tokens (RFC 8693).
- **Four logout levels**: this app, the device session, the browser session
  (RP-initiated logout) and everywhere.
- An optional **ready-to-use sign-in UI** driven by a typed configuration.

The exact HTTP contract the library expects from the server is in
[`doc/server-contract.md`](doc/server-contract.md).

## Packages

| Package | What | Platforms |
|---|---|---|
| `loginflow_auth` | Core, platform layer, sign-in UI | Android, iOS, macOS, web (Windows/Linux: see Limitations) |
| `packages/loginflow_auth_google` | Optional native Google ID token source | Android, iOS |

`import 'package:loginflow_auth/loginflow_auth_core.dart';` exposes only the
pure-Dart core (no Flutter imports). `loginflow_auth.dart` adds the platform
layer and the UI.

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
```

## Quick start (API only)

```dart
final auth = LoginFlowPlatform.createAuth(
  config: LoginFlowConfig(
    issuer: LoginFlowEnvironment.production.issuer,
    clientId: 'acme-orders-mobile',
    scopes: const ['profile', 'email'],
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

// Calling your API: always ask for a fresh token.
final token = await auth.accessToken(); // refreshes when needed
```

Every operation returns `Result<T, LoginFlowError>`; `LoginFlowError` is a
sealed hierarchy, so a `switch` over it is exhaustive.

Challenge steps: `requestEmailOtp`, `submitEmailOtp`, `resendEmailOtp`,
`submitPassword`, `submitTotp`, `submitRecoveryCode`, `selectMethod`,
`signInWithGoogle`, `signInWithMicrosoft`, `signUp`, `resetPassword`,
`cancelChallenge`. Step-up: `auth.stepUp(StepUpRequirement(acrValues: ['mfa']))`
or `StepUpRequirement.fromWwwAuthenticate(header)` from a 401 of your API
(RFC 9470).

Native SSO: when `initialize()` returns `SsoAvailable(candidate)`, show
"Continue as …" and call `continueWithSso()` or `declineSso()`. Call
`verifyDeviceSession()` when the app resumes so a device logout done by a
sibling app signs this one out too.

Logout: `auth.signOut(SignOutScope.app | device | browser | everywhere)`.

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
    googleIdTokenSource: const NativeGoogleIdTokenSource(), // optional package
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
  never shown; until the server answers, nothing unverified is shown.
- **One method** → the UI opens it directly (password form or email form;
  Google/Microsoft show their single button). Several → a method picker.
- **TOTP** → shown automatically whenever the server answers `next: totp`,
  with "use a recovery code" when the server offers it.
- **Sign-up** → "Create an account" only if `isSelfSignUpOffered` **and** the
  server enables self sign-up.
- **Forgot password** → only if `PasswordMethod.isForgotPasswordShown` **and**
  the server enables password reset.
- **Native SSO** → "Continue as …" when a sibling app is signed in.
- **Errors** → a message above the step (wrong credentials, expired code,
  offline, …); **429** → "Too many attempts" with a countdown from
  `Retry-After`.

`AuthMethod` is a sealed class with the implemented methods only. Passkeys
will be a new case when implemented; every `switch` over `AuthMethod` then
fails to compile until it handles them.

### Layout, theme, language, accessibility

- Screen class from the window's **shortest side**: mobile `< 600`,
  tablet `600–899`, desktop `≥ 900` (or width `≥ 1200`). Phones get a full
  screen; tablets and desktops a centered card. A phone in landscape stays
  mobile.
- Colors and typography come from your `ThemeData` (`ColorScheme`,
  `TextTheme`); spacing, radius, card width, logo height, button height and
  the loading bar thickness (1.5 px) come from `LoginFlowSignInTheme`.
- Texts in English and Spanish, chosen from the ambient locale; force one
  with `Localizations.override`.
- Fields carry autofill hints (`email`, `password`, `oneTimeCode`), titles are
  semantic headers, messages are live regions, and every action is at least
  48 dp tall.

The UI uses `reactive_notifier` internally; your app does not have to.

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

### Web

- Tokens live **in memory only**; a reload loses them. Restore the session
  with a silent top-level redirect, and complete the redirect on start-up:

  ```dart
  final auth = LoginFlowPlatform.createAuth(config: config);
  final started = await auth.initialize(launchUri: Uri.base); // completes a callback
  if (started case Ok(data: SignedOut(reason: SignOutReason.none))) {
    await auth.signInWithBrowser(prompt: AuthorizationPrompt.none);
  }
  // On SignedOut(reason: loginRequired) show a "Sign in" button that calls
  // auth.signInWithBrowser().
  ```

- The PKCE verifier, `state` and `nonce` survive the redirect in
  `sessionStorage` and are deleted as soon as the matching callback is
  consumed; a callback with another `state` or target is ignored, and a
  pending request expires after 10 minutes. The callback parameters are
  removed from the address bar.
- Refresh tokens of web clients last 24 h (absolute). When one expires the
  library signs out locally (`SignOutReason.sessionRevoked`); restore with
  `signInWithBrowser(prompt: AuthorizationPrompt.none)`.
- SSO across dashboard domains comes from the LoginFlow session cookie on the
  authorization server's own domain (top-level navigation, no iframes, no
  third-party cookies).

### Google (optional package)

- **Android**: create an *Android* OAuth client (package + SHA-1) and a *Web*
  client in the company's Google Cloud project; LoginFlow sends the web
  client ID as `serverClientId`. No manifest change.
- **iOS**: create an *iOS* OAuth client; add `GIDClientID` to `Info.plist`
  (or pass `NativeGoogleIdTokenSource(iosClientId: …)`) and the reversed
  client ID as a URL scheme in `CFBundleURLTypes`.
- Without the package, Google runs in the system browser through LoginFlow's
  hosted page.

## Security notes

- PKCE S256 on every authorization; `plain` is never sent.
- `state` and `iss` (RFC 9207) are checked before a code is redeemed.
- Refresh tokens rotate on every use; a rejected refresh clears the session.
- Refresh tokens are never shared between apps; Native SSO shares only the
  device secret and the ID token bound to it.
- Tokens, secrets and codes are never logged (`toString` of models that hold
  them is redacted).

## Limitations of 0.1.0

- No DPoP yet (see `doc/server-contract.md` §13).
- Windows and Linux: no secure storage or system browser implementation; the
  session lives in memory and browser steps fail as unavailable.
- Google and Microsoft buttons have no brand marks; add them per each
  provider's branding guidelines.

## Manual test plan (native)

The Dart layer and the pure Kotlin decisions are covered by automated tests.
These checks need a device and are not automated:

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
| 9 | Android, iOS | Google with `loginflow_auth_google` | Account sheet, then signed in |
| 10 | Android | While the Custom Tab is open, fire `adb shell am start -a android.intent.action.VIEW -d "<redirect URI>?code=x&state=forged"` | Nothing happens; the tab stays open and finishing the login still signs in |
| 11 | Android | Sign in, change the screen lock (invalidates Keystore keys), sign in again | The stored session is discarded once; the new sign-in persists normally |

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
