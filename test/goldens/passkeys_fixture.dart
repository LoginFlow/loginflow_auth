import 'package:loginflow_auth/loginflow_auth.dart';

/// Two enrolled passkeys for the manager goldens: one named and used, one
/// never named nor used. Fixed UTC dates at noon, so the day shown is the
/// same in any time zone the suite runs in (`TZ=UTC` in CI).
final List<PasskeyCredential> goldenPasskeys = <PasskeyCredential>[
  PasskeyCredential(
    id: 'credential-laptop',
    name: 'MacBook',
    createdAt: DateTime.utc(2026, 3, 14, 12),
    lastUsedAt: DateTime.utc(2026, 10, 2, 12),
  ),
  PasskeyCredential(
    id: 'credential-phone',
    name: null,
    createdAt: DateTime.utc(2026, 9, 1, 12),
    lastUsedAt: null,
  ),
];
