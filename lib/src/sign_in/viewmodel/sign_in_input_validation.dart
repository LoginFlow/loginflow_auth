import 'package:loginflow_auth/src/core/access_code/access_code_format.dart';
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

  /// Empty, or not the one shape the server issues ([AccessCodeFormat]):
  /// eight alphabet characters once spaces and the dash are dropped.
  FieldError toAccessCodeError() {
    if (trim().isEmpty) {
      return FieldError.required;
    }
    return AccessCodeFormat.isComplete(this)
        ? FieldError.none
        : FieldError.incompleteAccessCode;
  }
}
