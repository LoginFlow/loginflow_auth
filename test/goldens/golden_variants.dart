import 'package:flutter/material.dart';

import 'golden_test_harness.dart';

/// One light/dark × phone/tablet combination for a golden.
class GoldenVariant {
  const GoldenVariant(this.name, this.size, this.brightness);

  final String name;
  final Size size;
  final Brightness brightness;
}

/// The 4 combinations every screen is required to render: light/dark ×
/// phone/tablet (`doc/decisions.md` records the per-app language/branding
/// variants as additions on top of this baseline, not a replacement).
const baseGoldenVariants = <GoldenVariant>[
  GoldenVariant('phone_light', GoldenDeviceSize.phone, Brightness.light),
  GoldenVariant('phone_dark', GoldenDeviceSize.phone, Brightness.dark),
  GoldenVariant('tablet_light', GoldenDeviceSize.tablet, Brightness.light),
  GoldenVariant('tablet_dark', GoldenDeviceSize.tablet, Brightness.dark),
];
