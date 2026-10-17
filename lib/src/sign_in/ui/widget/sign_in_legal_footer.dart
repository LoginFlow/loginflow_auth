import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings.dart';
import 'package:loginflow_auth/src/sign_in/l10n/login_flow_strings_context.dart';
import 'package:loginflow_auth/src/sign_in/ui/theme/login_flow_sign_in_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Al continuar, aceptas los Términos y la Política de privacidad", with
/// the configured links (`SignInState.tosUri`/`.policyUri` —
/// `ClientLoginOptions.tosUri`/`.policyUri`, `doc/server-contract.md` §4).
/// Shows only the links the company actually configured; nothing at all
/// when neither is set. Each link opens in the system browser, never a
/// WebView (RFC 8252 §8.12) — a legal document is read-and-leave, not part
/// of the authorization-challenge flow, so this does not go through
/// `ExternalUserAgent` (which waits for an OAuth callback that will never
/// come here).
class SignInLegalFooter extends StatelessWidget {
  const SignInLegalFooter({this.policyUri, this.tosUri, super.key});

  final Uri? policyUri;
  final Uri? tosUri;

  @override
  Widget build(BuildContext context) {
    if (policyUri == null && tosUri == null) {
      return const SizedBox.shrink();
    }
    final strings = context.loginFlowStrings;
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final linkStyle = baseStyle?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.signInTheme.spacingSmall,
      ),
      child: Text.rich(
        TextSpan(
          children: _footerSpans(
            sentence: _sentence(strings),
            links: _links(strings),
            baseStyle: baseStyle,
            linkStyle: linkStyle,
          ),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _sentence(LoginFlowStrings strings) {
    if (tosUri != null && policyUri != null) {
      return strings.legalFooterBoth(
        strings.legalTermsLabel,
        strings.legalPrivacyLabel,
      );
    }
    if (tosUri != null) {
      return strings.legalFooterTermsOnly(strings.legalTermsLabel);
    }
    return strings.legalFooterPolicyOnly(strings.legalPrivacyLabel);
  }

  List<_LegalLink> _links(LoginFlowStrings strings) => [
    if (tosUri != null) _LegalLink(strings.legalTermsLabel, tosUri!),
    if (policyUri != null) _LegalLink(strings.legalPrivacyLabel, policyUri!),
  ];

  /// Splits [sentence] into plain-text and tappable [InlineSpan]s at each
  /// occurrence of a link's own label — the label is the exact
  /// substitution the ARB sentence was built with, so the search is exact,
  /// never fuzzy.
  List<InlineSpan> _footerSpans({
    required String sentence,
    required List<_LegalLink> links,
    required TextStyle? baseStyle,
    required TextStyle? linkStyle,
  }) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final link in links) {
      final start = sentence.indexOf(link.label, cursor);
      if (start < 0) {
        continue;
      }
      if (start > cursor) {
        spans.add(TextSpan(text: sentence.substring(cursor, start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _LegalLinkSpan(link: link, style: linkStyle),
        ),
      );
      cursor = start + link.label.length;
    }
    if (cursor < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(cursor)));
    }
    return spans
        .map(
          (span) => span is TextSpan && span.style == null
              ? TextSpan(text: span.text, style: baseStyle)
              : span,
        )
        .toList(growable: false);
  }
}

/// One legal document: its button label and its URL.
class _LegalLink {
  const _LegalLink(this.label, this.uri);

  final String label;
  final Uri uri;
}

/// A tappable word inside the footer sentence, with explicit link
/// semantics for screen readers.
class _LegalLinkSpan extends StatelessWidget {
  const _LegalLinkSpan({required this.link, required this.style});

  final _LegalLink link;
  final TextStyle? style;

  Future<void> _open() async {
    final launched = await launchUrl(
      link.uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      Log.w('Could not open legal link "${link.uri}" in the system browser.');
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: link.label,
    child: GestureDetector(
      onTap: () => unawaited(_open()),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(link.label, style: style),
      ),
    ),
  );
}
