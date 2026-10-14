/// Adaptive layout system: screen class from the window's shortest side.
///
/// Single import point:
///   import 'package:loginflow_auth/src/integrations/device/device.dart';
///
/// All detection logic lives in the enum + extension; widgets compute nothing.
library;

import 'package:flutter/widgets.dart';

part 'device_breakpoints.dart';
part 'device_context.dart';
part 'device_layout.dart';
part 'device_type.dart';
