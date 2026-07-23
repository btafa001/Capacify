import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => AnalyticsService.logScreenView('About'));
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: c.background,
      // Same plain back-arrow + title app bar as the legal subpages (AGB,
      // Datenschutz, Impressum) — this screen is reachable from both the
      // logged-out landing page AND Settings (logged-in), so a single
      // Navigator.pop() correctly returns to whichever pushed it, instead of
      // the previous logo-tap-to-home shortcut which assumed landing-only.
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.navAbout,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
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
