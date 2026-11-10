/// Why a scanned text is not a sign-in QR this app may answer
/// (`LoginFlowAuth.parseSignInQr`, `doc/server-contract.md` §21). Checked
/// on the device, before any request.
enum SignInQrProblem {
  /// Not a LoginFlow sign-in QR at all: not `https`, no `/qr/<id>` path,
  /// no secret in the fragment.
  malformed,

  /// A sign-in QR of another company: its host is not this app's
  /// `LoginFlowConfig.passkeyRpId`. Never sent anywhere.
  otherCompany,

  /// This app was not configured with its company's passkey host
  /// (`LoginFlowConfig.passkeyRpId`), so no QR can be checked.
  notConfigured,
}
