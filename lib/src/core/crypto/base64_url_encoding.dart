import 'dart:convert';
import 'dart:typed_data';

/// base64url without padding (RFC 7515 §2, RFC 7636 §3 "BASE64URL").
extension Base64UrlEncoding on List<int> {
  String toBase64UrlNoPadding() => base64Url.encode(this).replaceAll('=', '');
}

/// Decoding counterpart of [Base64UrlEncoding].
extension Base64UrlDecoding on String {
  /// Decodes unpadded base64url. Returns `null` when the text is not valid
  /// base64url (padding or characters outside the URL-safe alphabet).
  Uint8List? tryDecodeBase64Url() {
    if (contains('=') || contains('+') || contains('/')) {
      return null;
    }
    final padded = padRight(length + (4 - length % 4) % 4, '=');
    try {
      return base64Url.decode(padded);
    } on FormatException {
      return null;
    }
  }
}
