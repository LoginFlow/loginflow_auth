import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/integrations/device/device.dart';

void main() {
  group('DeviceType.fromSize', () {
    test('classifies by both edges of the shortest side', () {
      expect(DeviceType.fromSize(const Size(599, 900)), DeviceType.mobile);
      expect(DeviceType.fromSize(const Size(600, 900)), DeviceType.tablet);
      expect(DeviceType.fromSize(const Size(899, 1000)), DeviceType.tablet);
      expect(DeviceType.fromSize(const Size(900, 1000)), DeviceType.desktop);
    });

    test('a phone in landscape stays mobile', () {
      expect(DeviceType.fromSize(const Size(800, 400)), DeviceType.mobile);
    });

    test(
      'a very wide window is desktop even if its short side says tablet',
      () {
        expect(DeviceType.fromSize(const Size(1200, 700)), DeviceType.desktop);
      },
    );
  });
}
