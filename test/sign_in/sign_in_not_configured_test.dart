import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/loginflow_auth.dart';

void main() {
  testWidgets('without install the UI says it is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginFlowSignIn(onSignedIn: (_) {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign-in is not configured.'), findsOneWidget);
  });
}
