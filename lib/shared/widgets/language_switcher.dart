import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_theme.dart';

class LanguageSwitcher extends ConsumerWidget {
  final bool compact;
  const LanguageSwitcher({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final locale = ref.watch(localeProvider);
    final isDe = locale.languageCode == 'de';

    void setLocale(String lang) =>
        ref.read(localeProvider.notifier).state = Locale(lang);

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
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w900 : FontWeight.w500,
            color: active ? AppColors.primary : c.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
