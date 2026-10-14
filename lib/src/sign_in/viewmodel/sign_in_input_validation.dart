import 'package:loginflow_auth/src/sign_in/model/field_error.dart';

/// Client-side checks before anything is sent. The server stays the
/// authority; this only avoids round-trips for obviously empty or malformed
/// input.
extension SignInInputValidation on String {
  static final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  FieldError toEmailError() {
    final value = trim();
    if (value.isEmpty) {
      return FieldError.required;
    }
    return _emailShape.hasMatch(value)
        ? FieldError.none
        : FieldError.invalidEmail;
  }

  FieldError toRequiredError() =>
      trim().isEmpty ? FieldError.required : FieldError.none;
}
