import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/analytics_service.dart';

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => AnalyticsService.logScreenView('Impressum'));
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: c.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Impressum',
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
            constraints:
                const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // Required notice
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(
                      bottom: 32),
                  decoration: BoxDecoration(
                    color:
                        AppColors.error.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error
                          .withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        color: AppColors.error,
                        size: 16,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pflichtangaben gemäß §5 TMG. Muss vor dem Launch mit Ihren echten Unternehmensdaten ausgefüllt werden.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  'Impressum',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Angaben gemäß §5 TMG',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                _IPlaceholder(
                  title: 'Unternehmensangaben',
                  fields: const [
                    'Firmenname: [Eintragen]',
                    'Rechtsform: [z.B. GmbH, UG, GbR]',
                    'Adresse: [Straße, PLZ, Ort]',
                    'Telefon: [Eintragen]',
                    'E-Mail: [Eintragen]',
                  ],
                ),

                _IPlaceholder(
                  title: 'Vertretungsberechtigte Person',
                  fields: const [
                    'Vertreten durch: [Geschäftsführer / Inhaber]',
                  ],
                ),

                _IPlaceholder(
                  title: 'Steuer- und Registerangaben',
                  fields: const [
                    'Umsatzsteuer-ID: [falls vorhanden]',
                    'Handelsregisternummer: [falls vorhanden]',
                    'Registergericht: [falls vorhanden]',
                  ],
                ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius:
                        BorderRadius.circular(8),
                    border:
                        Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Haftungsausschluss',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Die Inhalte dieser Plattform wurden mit größtmöglicher Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte kann Capacify jedoch keine Gewähr übernehmen.',
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
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

// ── Widget private to this file ──

class _IPlaceholder extends StatelessWidget {
  final String title;
  final List<String> fields;

  const _IPlaceholder({
    required this.title,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    AppColors.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Vor Launch ausfüllen',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...fields.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: 6),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}