/// An in-app password reset under way (`LoginFlowAuth.startPasswordReset`):
/// the address the code went to and, once the code signed the person in,
/// the session held back until the new password is set.
///
/// Internal flow state; never persisted, so no `toJson`/`fromJson`.
class PasswordReset {
  const PasswordReset({
    required this.email,
    this.isSessionHeld = false,
    this.deviceSecret,
    this.newPassword,
  });

  /// The address the reset started with.
  final String email;

  /// The code signed the person in: `LoginFlowAuth` holds that session in
  /// memory — unstored and unannounced — until the new password is set.
  final bool isSessionHeld;

  /// The `device_secret` that came with the held session, written to the
  /// Native SSO store only once the reset completes.
  final String? deviceSecret;

  /// The new password the server asked a step-up for, sent again once the
  /// step-up completes. In memory only, for the length of the step-up.
  final String? newPassword;

  /// This reset holding the session the code signed in.
  PasswordReset holding({required String? deviceSecret}) => PasswordReset(
    email: email,
    isSessionHeld: true,
    deviceSecret: deviceSecret ?? this.deviceSecret,
    newPassword: newPassword,
  );

  /// This reset with no password waiting for a step-up.
  PasswordReset withoutNewPassword() => PasswordReset(
    email: email,
    isSessionHeld: isSessionHeld,
    deviceSecret: deviceSecret,
  );

  PasswordReset copyWith({
    String? email,
    bool? isSessionHeld,
    String? deviceSecret,
    String? newPassword,
  }) => PasswordReset(
    email: email ?? this.email,
    isSessionHeld: isSessionHeld ?? this.isSessionHeld,
    deviceSecret: deviceSecret ?? this.deviceSecret,
    newPassword: newPassword ?? this.newPassword,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasswordReset &&
          email == other.email &&
          isSessionHeld == other.isSessionHeld &&
          deviceSecret == other.deviceSecret &&
          newPassword == other.newPassword;

  @override
  int get hashCode =>
      Object.hash(email, isSessionHeld, deviceSecret, newPassword);

  @override
  String toString() => 'PasswordReset(isSessionHeld: $isSessionHeld)';
}
