/// Why a form field was refused before anything was sent.
enum FieldError {
  none,
  required,
  invalidEmail,

  /// An access code shorter than `AccessCodeFormat.length`, or with
  /// characters outside `AccessCodeFormat.alphabet`.
  incompleteAccessCode,
}
