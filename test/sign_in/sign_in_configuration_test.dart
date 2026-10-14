import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';

void main() {
  test('the configuration round-trips through JSON', () {
    const configuration = SignInConfiguration(
      methods: <AuthMethod>[
        PasswordMethod(isForgotPasswordShown: false),
        EmailOtpMethod(resendCooldown: Duration(seconds: 45)),
        GoogleMethod(),
        MicrosoftMethod(),
      ],
      isSelfSignUpOffered: true,
      copy: SignInCopy(
        title: LocalizedText(english: 'Welcome', spanish: 'Bienvenido'),
      ),
    );

    expect(SignInConfiguration.fromJson(configuration.toJson()), configuration);
  });

  test('an unknown method name is refused, not ignored', () {
    expect(
      () => AuthMethod.fromJson(const <String, Object?>{'method': 'carrier'}),
      throwsFormatException,
    );
  });
}
