import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/consent_provider.dart';

/// GDPR/TTDSG cookie-consent bar. Shown only while the choice is undecided,
/// pinned to the bottom above all content. "Ablehnen" is presented with equal
/// weight to "Akzeptieren" (no dark-pattern nudging), and analytics stays off
/// until an explicit accept. Wrap the app's home with [ConsentGate].
class ConsentGate extends ConsumerWidget {
  final Widget child;
  const ConsentGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(consentProvider);
    return Stack(
      children: [
        child,
        if (consent == ConsentState.undecided)
          const Positioned(left: 0, right: 0, bottom: 0, child: _ConsentBar()),
      ],
    );
  }
}

class _ConsentBar extends ConsumerWidget {
  const _ConsentBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 720;

    final text = Text.rich(
      TextSpan(
        style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        children: [
          TextSpan(text: l.consentBody),
          const TextSpan(text: '  '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              onTap: () => context.push(Routes.privacy),
              child: Text(l.consentLearnMore,
                  style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );

    final buttons = [
      OutlinedButton(
        onPressed: () => ref.read(consentProvider.notifier).deny(),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          minimumSize: const Size(120, 44),
        ),
        child: Text(l.consentDecline, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 12),
      ElevatedButton(
        onPressed: () => ref.read(consentProvider.notifier).grant(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(120, 44),
        ),
        child: Text(l.consentAccept, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    ];

    return Material(
      elevation: 16,
      color: c.surface,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        text,
                        const SizedBox(height: 14),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: buttons),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: text),
                        const SizedBox(width: 20),
                        ...buttons,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
