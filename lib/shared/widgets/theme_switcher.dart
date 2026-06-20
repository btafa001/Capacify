import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/theme_provider.dart';

class ThemeSwitcher extends ConsumerWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    final c = AppColors.of(context);

    return Tooltip(
      message: isDark ? 'Light mode' : 'Dark mode',
      child: GestureDetector(
        onTap: () => ref.read(themeModeProvider.notifier).state =
            isDark ? ThemeMode.light : ThemeMode.dark,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                isDark ? 'Dark' : 'Light',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
