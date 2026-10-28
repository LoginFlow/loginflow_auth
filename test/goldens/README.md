# Sign-in UI goldens

One golden test file per screen/widget of the built-in sign-in flow. Each
file renders that screen's `SignInState` through the real public widget,
`LoginFlowSignIn`, so the device-type rule (`DeviceLayout`, shortest side —
`lib/src/integrations/device/device_type.dart`), the theme extension
(`LoginFlowSignInTheme`) and the locale service all run exactly as they do
in a host app, not a reimplementation of the layout.

## Layout

```
test/goldens/
  golden_test_harness.dart   — pumpSignInGolden(), device sizes, the custom
                                branding theme, a stand-in logo widget
  golden_variants.dart       — the 4 baseline combinations every screen
                                renders at
  <screen>_golden_test.dart  — one file per screen
  <screen>/<variant>.png     — the golden images themselves
```

A screen with more than one visually distinct state (e.g. the TOTP step
and its recovery-code variant) gets its own test file rather than a case
folded into another screen's — one golden per widget, never a shared
mega-file.

## Screens covered

| Screen | File |
|---|---|
| Identifier/email | `identifier_golden_test.dart` |
| Method picker (password, Google, Microsoft, Apple, Facebook, email code, passkey, sign-up) | `method_picker_golden_test.dart` |
| Password | `password_golden_test.dart` |
| OTP code | `otp_golden_test.dart` |
| Password reset: code (resend cooldown running) | `reset_code_golden_test.dart` |
| Password reset: new password (mismatch error) | `new_password_golden_test.dart` |
| Magic link offered | `magic_link_golden_test.dart` |
| TOTP | `totp_golden_test.dart` |
| Recovery code | `recovery_code_golden_test.dart` |
| Temporary Access Pass (TAP) | `temporary_access_pass_golden_test.dart` |
| Passkey prompt / failure | `passkey_golden_test.dart` |
| Lockout countdown | `lockout_golden_test.dart` |
| Generic error | `generic_error_golden_test.dart` |
| Progress bar (busy) | `progress_bar_golden_test.dart` |
| SSO confirm ("Continue as …") | `sso_confirm_golden_test.dart` |
| Redirect-to-web notice | `redirect_to_web_golden_test.dart` |
| Access code step | `access_code_golden_test.dart` |
| Access code refused (only entry screen, no "Back") | `access_code_error_golden_test.dart` |
| Method picker with "I have an access code" | `access_code_entry_golden_test.dart` |
| Passkey manager: list | `passkeys_list_golden_test.dart` |
| Passkey manager: empty | `passkeys_empty_golden_test.dart` |
| Passkey manager: ceremony failure (real reason) | `passkeys_failure_golden_test.dart` |
| Passkey manager: re-authentication (step-up) | `passkeys_reauthentication_golden_test.dart` |
| Passkey manager: rename dialog | `passkeys_rename_dialog_golden_test.dart` |
| Passkey manager: delete confirmation | `passkeys_delete_dialog_golden_test.dart` |

Every screen renders the 4 baseline combinations (`golden_variants.dart`):
`phone_light`, `phone_dark`, `tablet_light`, `tablet_dark`. The identifier
screen additionally renders `phone_light_en` (the only screen required to
prove the `en` locale, per the task); the identifier, method-picker and
password screens — the ones a host app is most likely to brand — also
render `phone_light_custom_branding`, a theme that differs from the
default in every token `LoginFlowSignInTheme` exposes (seed color via the
host `ColorScheme`, corner radius, card width, spacing, action height,
card color) plus a stand-in logo widget.

There is no `redirect-to-web` screen separate from
`SignInAwaitingBrowser`, and no dedicated "magic link sent" screen: the
protocol sends the magic link to the same inbox message as the code
already sent, so `OtpStep` with `isMagicLinkOffered: true` is both. A
passkey's OS-native sheet (Credential Manager, AuthenticationServices) is
platform chrome this library never draws; `passkey_golden_test.dart`
goldens the two states the library's own UI shows around it — the
"Continue with a passkey" button and the failure banner.

The passkey manager screens render the public `LoginFlowPasskeys` through
`pumpPasskeysGolden` (same harness rules), with the state forced on
`PasskeysService.manager`; the re-authentication golden also forces the
sign-in flow state, since that step renders the sign-in steps. The two
dialogs are opened by tapping their tile action, then pumped a fixed
300 ms (no `pumpAndSettle`). Passkey dates are fixed UTC noons
(`passkeys_fixture.dart`), so the day shown never depends on the time
zone.

## Why no network, no `LoginFlowSignInSetup.install`

Every `SignInState` is forced directly on `SignInService.flow.notifier`
with the real public `ViewModel.updateState` — the same method the
ViewModel itself uses for every transition. A golden tests pixels, not the
authorization-challenge flow (that is `test/sign_in/sign_in_widget_test.dart`'s
job); driving every screen through a fake server would make 56 of the 64
goldens about exercising network code paths that are already covered
elsewhere, not about the screen.

`ViewModel.init()` runs the first time a consumer widget mounts and resets
the state to `SignInNotConfigured` (no environment installed) — so
`pumpSignInGolden` forces the state **after** `pumpWidget`, then pumps once
more. Forcing it before `pumpWidget` is silently overwritten by `init()`
and was an actual bug caught while building this harness (every screen
rendered as the "not configured" message until this was found).

## Determinism

- Fixed window size (`GoldenDeviceSize.phone` / `.tablet`, shortest side
  390 / 700 respectively — `DeviceType.fromSize` lands them in the mobile
  and tablet bands) and `devicePixelRatio: 1`.
- `TextScaler.noScaling` — a change in the test machine's default text
  scale never moves a golden.
- A fixed `Locale` per golden (`es` as the base locale, one `en` variant on
  the identifier screen — `LoginFlowLocaleService.setLocale` forces it
  regardless of the ambient `Localizations`).
- No custom font is declared in `pubspec.yaml`, so there is nothing for a
  golden to load: Flutter's test environment always renders text with its
  own bundled, version-locked test font rather than a real one, which is
  already deterministic across machines without extra setup. Recorded as a
  decision (`doc/decisions.md`) because the task described loading a
  bundled font explicitly — there was no font to load, by construction.
- No animation is ever pumped past frame zero: `pumpSignInGolden` calls
  `tester.pump()` with no duration, so an indeterminate
  `LinearProgressIndicator` (the busy progress bar) always renders at its
  initial, reproducible frame. No `Timer`s are started — nothing in these
  tests calls a ViewModel method, only `updateState`.
- `debugShowCheckedModeBanner: false` so the debug ribbon never pollutes a
  diff.

## Running and regenerating

```sh
# Verify against the committed images (CI does this)
TZ=UTC flutter test test/goldens/

# Regenerate after an intentional visual change
TZ=UTC flutter test test/goldens/ --update-goldens
```

**Never run `--update-goldens` blindly.** Before regenerating:

1. Run without `--update-goldens` first and read which goldens actually
   failed and why (`git diff --stat` after a run tells you nothing by
   itself — look at the failure output).
2. Open the failing `.png` (or use `flutter test`'s own diff output) and
   confirm the change is the one you intended — a layout regression and an
   intentional restyle produce the same "golden changed" signal; only a
   human looking at the image tells them apart.
3. Regenerate only the affected file(s)
   (`flutter test test/goldens/<file>.dart --update-goldens`), not the
   whole directory, unless the change is genuinely global (e.g. a new
   `LoginFlowSignInTheme` default).
4. State the cause in the commit/PR: which widget changed and why the new
   pixels are correct.
