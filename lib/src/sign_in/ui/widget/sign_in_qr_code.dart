import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// [data] drawn as a QR code: black modules on white with the 4-module
/// quiet zone the standard asks for, whatever the app's theme, so any
/// camera reads it.
class SignInQrCode extends StatelessWidget {
  const SignInQrCode({
    required this.data,
    required this.semanticLabel,
    this.size = 224,
    super.key,
  });

  final String data;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _QrCodePainter(data)),
    ),
  );
}

class _QrCodePainter extends CustomPainter {
  _QrCodePainter(this.data);

  /// The quiet zone around the code, in modules (ISO/IEC 18004 §6.3.8).
  static const int _quietZone = 4;

  final String data;

  late final QrImage _image = QrImage(
    QrCode(payload: QrPayload.fromString(data)),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final modules = _image.moduleCount + 2 * _quietZone;
    final module = size.shortestSide / modules;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final dark = Paint()..color = Colors.black;
    for (var row = 0; row < _image.moduleCount; row++) {
      for (var column = 0; column < _image.moduleCount; column++) {
        if (_image.isDark(row, column)) {
          canvas.drawRect(
            Rect.fromLTWH(
              (column + _quietZone) * module,
              (row + _quietZone) * module,
              module,
              module,
            ),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrCodePainter oldDelegate) => oldDelegate.data != data;
}
