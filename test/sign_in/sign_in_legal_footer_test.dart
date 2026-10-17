import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loginflow_auth/src/sign_in/ui/widget/sign_in_legal_footer.dart';

void main() {
  final policyUri = Uri.parse('https://acme.example/privacy');
  final tosUri = Uri.parse('https://acme.example/terms');

  Future<void> pump(
    WidgetTester tester, {
    Uri? policyUri,
    Uri? tosUri,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SignInLegalFooter(policyUri: policyUri, tosUri: tosUri),
      ),
    ),
  );

  group('SignInLegalFooter', () {
    testWidgets('renders nothing when neither link is configured', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(SignInLegalFooter), findsOneWidget);
      expect(find.text('Términos'), findsNothing);
      expect(find.text('Política de privacidad'), findsNothing);
    });

    testWidgets('renders only the terms link when only tosUri is set', (
      tester,
    ) async {
      await pump(tester, tosUri: tosUri);

      expect(find.text('Términos'), findsOneWidget);
      expect(find.text('Política de privacidad'), findsNothing);
    });

    testWidgets('renders only the privacy link when only policyUri is set', (
      tester,
    ) async {
      await pump(tester, policyUri: policyUri);

      expect(find.text('Política de privacidad'), findsOneWidget);
      expect(find.text('Términos'), findsNothing);
    });

    testWidgets('renders both links with link semantics when both are set', (
      tester,
    ) async {
      await pump(tester, policyUri: policyUri, tosUri: tosUri);

      expect(find.text('Términos'), findsOneWidget);
      expect(find.text('Política de privacidad'), findsOneWidget);

      final termsSemantics = tester.getSemantics(find.text('Términos'));
      expect(termsSemantics.flagsCollection.isLink, isTrue);
      final policySemantics = tester.getSemantics(
        find.text('Política de privacidad'),
      );
      expect(policySemantics.flagsCollection.isLink, isTrue);
    });
  });
}
