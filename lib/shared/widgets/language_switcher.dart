import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_theme.dart';
import 'interactions.dart';

class LanguageSwitcher extends ConsumerWidget {
  final bool compact;
  final bool iconOnly;
  const LanguageSwitcher({super.key, this.compact = false, this.iconOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final locale = ref.watch(localeProvider);
    final isDe = locale.languageCode == 'de';

    void setLocale(String lang) =>
        ref.read(localeProvider.notifier).setLocale(Locale(lang));

    if (iconOnly) {
      // The visible text is the CURRENT language ("DE"), but tapping switches
      // to the other one — so the announced label is the tooltip's target
      // language, not the glyph.
      return Tooltip(
        message: isDe ? 'English' : 'Deutsch',
        child: Semantics(
          container: true,
          button: true,
          label: isDe ? 'English' : 'Deutsch',
          child: InkWell(
            onTap: () => setLocale(isDe ? 'en' : 'de'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
              ),
              // Excluded here, not via Semantics.excludeSemantics — that would
              // drop the InkWell's own tap action along with it, leaving a
              // button a screen reader can name but not press.
              child: ExcludeSemantics(
                child: Text(
                  isDe ? 'DE' : 'EN',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(label: 'DE', active: isDe, onTap: () => setLocale('de')),
          Container(
            width: 1,
            height: 12,
            color: c.border,
            margin: const EdgeInsets.symmetric(horizontal: 5),
          ),
          _Btn(label: 'EN', active: !isDe, onTap: () => setLocale('en')),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(label: 'DE', active: isDe, onTap: () => setLocale('de')),
          Container(
            width: 1,
            height: 12,
            color: c.border,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          _Btn(label: 'EN', active: !isDe, onTap: () => setLocale('en')),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // The DE/EN pair in the landing header. `selected` rather than plain
    // `button` so a screen reader announces which language is currently
    // active, not just that these are two pressable things.
    return HoverTextLink(
      label: label,
      onTap: onTap,
      semanticsSelected: active,
      style: (context, _) => TextStyle(
        fontSize: 12,
        fontWeight: active ? FontWeight.w900 : FontWeight.w500,
        color: active ? AppColors.primary : c.textTertiary,
        letterSpacing: 0.3,
      ),
    );
  }
}
