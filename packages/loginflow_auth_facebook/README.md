# loginflow_auth_facebook

Optional native Continue with Facebook for `loginflow_auth`. It implements
`UpstreamTokenSource` with the
[`flutter_facebook_auth`](https://pub.dev/packages/flutter_facebook_auth)
package: Limited Login on iOS (an OIDC ID token carrying the server's
nonce) and classic login on Android (an access token, nonceless — the real
Facebook SDK split, not a LoginFlow choice). Apps that do not offer Facebook
do not add this package and carry no Facebook SDK dependency.

```dart
final auth = LoginFlowPlatform.createAuth(
  config: config,
  facebookTokenSource: NativeFacebookTokenSource(),
);
```

With no source registered, `signInWithFacebook()` falls back to the hosted
page in the system browser (never a `WebView`), the same way Google does
today without `loginflow_auth_google`.

## Setup

1. Create/configure the app in [Meta for Developers](https://developers.facebook.com/)
   and add the **Facebook Login** product.
2. **Android** — `android/app/src/main/res/values/strings.xml`:
   ```xml
   <string name="facebook_app_id">YOUR_APP_ID</string>
   <string name="facebook_client_token">YOUR_CLIENT_TOKEN</string>
   <string name="fb_login_protocol_scheme">fbYOUR_APP_ID</string>
   ```
   and the matching `<meta-data>`/`<activity>` entries in
   `AndroidManifest.xml` per the `flutter_facebook_auth` package's own setup
   guide (Facebook's key hash must also be registered on the Facebook app's
   Android settings page).
3. **iOS** — `ios/Runner/Info.plist`: `FacebookAppID`, `FacebookClientToken`,
   `FacebookDisplayName`, the `fbYOUR_APP_ID` URL scheme, and
   `LSApplicationQueriesSchemes` entries for `fbapi`/`fb-messenger-share-api`,
   again per the package's setup guide.
4. The company's **Facebook App ID** must match what LoginFlow publishes as
   `ClientLoginOptions.facebookAppId` from `GET /oauth2/login-options` — the
   built-in sign-in UI shows the Facebook button only when the server lists
   `facebook` there, same gating as every other method.

## Limited Login vs classic login

iOS always uses Limited Login (Apple's App Tracking Transparency rules make
classic Facebook Login impractical there); Android always uses classic
login. `NativeFacebookTokenSource` picks the right one and reports the
resulting token's shape to the server as `upstream_token_type`
(`id_token` or `access_token`) — the app never has to branch on platform
itself.

Setup is described in the main README, section "Facebook (optional
package)".
