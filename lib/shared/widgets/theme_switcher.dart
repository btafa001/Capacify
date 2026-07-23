import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/theme_provider.dart';

class ThemeSwitcher extends ConsumerWidget {
  final bool iconOnly;
  const ThemeSwitcher({super.key, this.iconOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    final c = AppColors.of(context);

    // InkWell, not GestureDetector: this sits in the landing header, where a
    // keyboard user has to be able to reach it. The tooltip message doubles as
    // the semantic label — the icon-only variant has no text of its own for a
    // screen reader to announce.
    return Tooltip(
      message: isDark ? 'Light mode' : 'Dark mode',
      child: Semantics(
        container: true,
        button: true,
        label: isDark ? 'Light mode' : 'Dark mode',
        child: InkWell(
          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: iconOnly
              ? const EdgeInsets.all(7)
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          // The visible "Dark"/"Light" text names the CURRENT mode while the
          // label names what tapping switches to — announcing both would read
          // as "Dark mode, button, Light". Excluded here rather than via
          // Semantics.excludeSemantics, which would take the InkWell's tap
          // action with it.
          child: ExcludeSemantics(
            child: iconOnly
              ? Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 16,
                  color: AppColors.primary,
                )
              : Row(
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
        ),
      ),
    );
  }
}
