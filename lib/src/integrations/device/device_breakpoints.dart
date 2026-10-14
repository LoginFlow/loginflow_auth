part of 'device.dart';

/// Material 3 window-size breakpoints, in logical pixels.
abstract final class DeviceBreakpoints {
  /// shortestSide < 600 => mobile.
  static const double mobileMaxShortestSide = 600;

  /// shortestSide >= 900 => desktop.
  static const double desktopMinShortestSide = 900;

  /// window width >= 1200 => desktop (wide but short laptop or web windows).
  static const double desktopMinWidth = 1200;
}
