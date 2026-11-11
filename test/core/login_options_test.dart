import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth_core.dart';

void main() {
  group('ClientLoginOptions.fromJson — policy_uri/tos_uri', () {
    Map<String, Object?> baseJson({String? policyUri, String? tosUri}) => {
      'client_id': 'acme-mobile',
      'login_methods': <String>['password'],
      'self_signup': false,
      'password_reset': false,
      'policy_uri': ?policyUri,
      'tos_uri': ?tosUri,
    };

    test('parses both when the server configures both', () {
      final options = ClientLoginOptions.fromJson(
        baseJson(
          policyUri: 'https://acme.example/privacy',
          tosUri: 'https://acme.example/terms',
        ),
      );

      expect(options.policyUri, Uri.parse('https://acme.example/privacy'));
      expect(options.tosUri, Uri.parse('https://acme.example/terms'));
    });

    test('both are null when the server omits them', () {
      final options = ClientLoginOptions.fromJson(baseJson());

      expect(options.policyUri, isNull);
      expect(options.tosUri, isNull);
    });

    test('a non-https value is treated as omitted, not a parse failure', () {
      final options = ClientLoginOptions.fromJson(
        baseJson(policyUri: 'http://acme.example/privacy'),
      );

      expect(options.policyUri, isNull);
    });

    test('round-trips through toJson/fromJson', () {
      final original = ClientLoginOptions.fromJson(
        baseJson(
          policyUri: 'https://acme.example/privacy',
          tosUri: 'https://acme.example/terms',
        ),
      );

      final restored = ClientLoginOptions.fromJson(original.toJson());

      expect(restored, original);
    });
  });
  group('ClientLoginOptions.fromJson — account_recovery', () {
    Map<String, Object?> baseJson({bool? accountRecovery}) => {
      'client_id': 'acme-mobile',
      'login_methods': <String>['password'],
      'self_signup': false,
      'password_reset': false,
      'account_recovery': ?accountRecovery,
    };

    test('reads account_recovery when the server publishes it', () {
      final options = ClientLoginOptions.fromJson(
        baseJson(accountRecovery: true),
      );

      expect(options.isAccountRecoveryEnabled, isTrue);
      expect(options.toJson()['account_recovery'], isTrue);
    });

    test('an absent account_recovery means off', () {
      final options = ClientLoginOptions.fromJson(baseJson());

      expect(options.isAccountRecoveryEnabled, isFalse);
      expect(options.toJson()['account_recovery'], isFalse);
    });

    test('round-trips through toJson/fromJson', () {
      final original = ClientLoginOptions.fromJson(
        baseJson(accountRecovery: true),
      );

      final restored = ClientLoginOptions.fromJson(original.toJson());

      expect(restored.toJson()['account_recovery'], isTrue);
      expect(restored, original);
    });
  });
}
