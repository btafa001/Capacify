import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.navAbout,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capacify',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l.aboutParagraph1,
                  style: TextStyle(
                    fontSize: 16,
                    color: c.textSecondary,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  l.aboutParagraph2,
                  style: TextStyle(
                    fontSize: 16,
                    color: c.textSecondary,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  l.aboutNoTenders,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.aboutRightCapacity,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
