import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

/// SHA-256 over raw bytes.
extension Sha256Hashing on List<int> {
  Uint8List toSha256() => SHA256Digest().process(Uint8List.fromList(this));
}
