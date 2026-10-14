/// Big-endian unsigned integer conversions used by JWK and JWS encodings
/// (RFC 7518 §2 "Base64urlUInt", §3.4 ECDSA `R || S`).
extension UnsignedBigIntDecoding on List<int> {
  BigInt toUnsignedBigInt() {
    var value = BigInt.zero;
    for (final byte in this) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }
}

/// Fixed-length big-endian encoding of a non-negative [BigInt].
extension UnsignedBigIntEncoding on BigInt {
  List<int> toUnsignedBytes(int length) {
    final bytes = List<int>.filled(length, 0);
    var remaining = this;
    for (var index = length - 1; index >= 0; index--) {
      bytes[index] = (remaining & BigInt.from(0xff)).toInt();
      remaining = remaining >> 8;
    }
    return bytes;
  }
}
