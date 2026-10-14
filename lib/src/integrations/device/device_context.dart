part of 'device.dart';

/// Classification read from the context; raw measures are not exposed.
extension DeviceContext on BuildContext {
  DeviceType get deviceType => DeviceType.fromSize(MediaQuery.sizeOf(this));
}
