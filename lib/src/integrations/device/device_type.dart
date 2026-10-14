part of 'device.dart';

/// Device class by WINDOW size, decided by the shortest side so a phone in
/// landscape is never mistaken for a tablet.
enum DeviceType {
  mobile,
  tablet,
  desktop;

  static DeviceType fromSize(Size size) {
    final shortestSide = size.shortestSide;
    if (shortestSide < DeviceBreakpoints.mobileMaxShortestSide) {
      return DeviceType.mobile;
    }
    if (shortestSide >= DeviceBreakpoints.desktopMinShortestSide ||
        size.width >= DeviceBreakpoints.desktopMinWidth) {
      return DeviceType.desktop;
    }
    return DeviceType.tablet;
  }
}
