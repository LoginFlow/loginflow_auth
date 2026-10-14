part of 'device.dart';

/// Renders the widget for the current [DeviceType]. Routing only.
class DeviceLayout extends StatelessWidget {
  const DeviceLayout({
    required this.mobile,
    required this.tablet,
    required this.desktop,
    super.key,
  });

  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  @override
  Widget build(BuildContext context) => switch (context.deviceType) {
    DeviceType.mobile => mobile,
    DeviceType.tablet => tablet,
    DeviceType.desktop => desktop,
  };
}
