import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
import '../../../shared/widgets/capacify_logo.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/register_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => AnalyticsService.logScreenView('About'));
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: c.background,
      // Persistent marketing top bar — the logo returns home and Login/Register
      // are always reachable, so the page isn't a back-button dead end.
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
          child: CapacifyWordmark(symbolSize: 28, fontSize: 18, textColor: c.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: Text(l.navLogin, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(isMobile ? l.navStartFreeMobile : l.navStartFree,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
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
