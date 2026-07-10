import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/analytics_service.dart';

class AGBScreen extends StatelessWidget {
  const AGBScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => AnalyticsService.logScreenView('AGB'));
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
          'Allgemeine Geschäftsbedingungen',
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
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Draft notice
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.accent,
                        size: 16,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Entwurf – Diese AGB wurden noch nicht rechtsanwaltlich geprüft. Bitte vor dem Launch durch einen deutschen IT-Rechtsanwalt prüfen lassen.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const _LegalTitle(
                  text:
                      'Allgemeine Geschäftsbedingungen (AGB)',
                ),

                const SizedBox(height: 32),

                const _LegalSection(
                  number: '1.',
                  title: 'Geltungsbereich',
                  paragraphs: [
                    'Diese Allgemeinen Geschäftsbedingungen regeln die Nutzung der Plattform „Capacify" durch Unternehmen und gewerbliche Nutzer.',
                    'Capacify stellt eine digitale Plattform zur Verfügung, über die Unternehmen Kapazitäten, Personalbedarf, Projektanfragen und sonstige geschäftliche Informationen veröffentlichen und miteinander in Kontakt treten können.',
                  ],
                ),

                const _LegalSection(
                  number: '2.',
                  title: 'Rolle von Capacify',
                  paragraphs: [
                    'Capacify stellt ausschließlich die technische Infrastruktur für die Vernetzung von Unternehmen bereit.',
                    'Capacify ist weder Auftraggeber noch Auftragnehmer der über die Plattform vermittelten Leistungen.',
                    'Verträge kommen ausschließlich zwischen den beteiligten Unternehmen zustande.',
                    'Capacify wird nicht Vertragspartei und übernimmt keine Vertretung der Nutzer.',
                  ],
                ),

                const _LegalSection(
                  number: '3.',
                  title: 'Registrierung',
                  paragraphs: [
                    'Die Nutzung setzt die Registrierung eines Unternehmenskontos voraus.',
                    'Der Nutzer bestätigt, dass die bei der Registrierung angegebenen Daten vollständig und korrekt sind.',
                  ],
                ),

                const _LegalSection(
                  number: '4.',
                  title: 'Unternehmensangaben',
                  paragraphs: [
                    'Nutzer sind verpflichtet, wahrheitsgemäße Angaben zu machen.',
                    'Hierzu zählen insbesondere:',
                  ],
                  bulletPoints: [
                    'Firmenname',
                    'Anschrift',
                    'Gewerbliche Tätigkeit',
                    'Ansprechpartner',
                    'Kontaktdaten',
                  ],
                ),

                const _LegalSection(
                  number: '5.',
                  title: 'Veröffentlichte Inhalte',
                  paragraphs: [
                    'Nutzer sind für sämtliche veröffentlichten Inhalte selbst verantwortlich.',
                    'Capacify ist nicht verpflichtet, Inhalte vor Veröffentlichung zu prüfen.',
                    'Capacify behält sich das Recht vor, Inhalte zu entfernen, wenn diese:',
                  ],
                  bulletPoints: [
                    'rechtswidrig sind',
                    'irreführend sind',
                    'gegen diese AGB verstoßen',
                  ],
                ),

                const _LegalSection(
                  number: '6.',
                  title: 'Keine Gewährleistung',
                  paragraphs: [
                    'Capacify übernimmt keine Gewähr für:',
                  ],
                  bulletPoints: [
                    'die Verfügbarkeit von Personal',
                    'die Ausführung von Leistungen',
                    'die Qualität der Leistungen',
                    'die Bonität eines Nutzers',
                    'die Richtigkeit von Angaben',
                    'den Erfolg eines Geschäftsabschlusses',
                  ],
                ),

                const _LegalSection(
                  number: '7.',
                  title: 'Verifizierung',
                  paragraphs: [
                    'Eine Verifizierung bestätigt ausschließlich, dass bestimmte Informationen oder Dokumente geprüft wurden.',
                    'Eine Verifizierung stellt keine Garantie für Qualität, Zuverlässigkeit, Leistungsfähigkeit oder Vertragstreue dar.',
                  ],
                ),

                const _LegalSection(
                  number: '8.',
                  title: 'Eigenverantwortung',
                  paragraphs: [
                    'Jeder Nutzer ist verpflichtet, Geschäftspartner eigenständig zu prüfen.',
                    'Capacify empfiehlt insbesondere die Prüfung von:',
                  ],
                  bulletPoints: [
                    'Gewerbeanmeldung',
                    'Referenzen',
                    'Versicherungen',
                    'Qualifikationen',
                  ],
                ),

                const _LegalSection(
                  number: '9.',
                  title: 'Arbeitnehmerüberlassung',
                  paragraphs: [
                    'Capacify bietet keine Arbeitnehmerüberlassung an.',
                    'Capacify beschäftigt keine Arbeitnehmer zur Weitervermittlung.',
                    'Nutzer handeln ausschließlich im eigenen Namen und auf eigene Verantwortung.',
                  ],
                ),

                const _LegalSection(
                  number: '10.',
                  title: 'Haftung',
                  paragraphs: [
                    'Soweit gesetzlich zulässig, haftet Capacify nur für vorsätzlich oder grob fahrlässig verursachte Schäden.',
                    'Eine Haftung für folgende Schäden ist ausgeschlossen:',
                  ],
                  bulletPoints: [
                    'Projektverzögerungen',
                    'Umsatzausfälle',
                    'entgangenen Gewinn',
                    'indirekte Schäden',
                  ],
                ),

                const _LegalSection(
                  number: '11.',
                  title: 'Sperrung von Konten',
                  paragraphs: [
                    'Capacify kann Nutzerkonten sperren oder löschen, wenn:',
                  ],
                  bulletPoints: [
                    'gegen Gesetze verstoßen wird',
                    'falsche Angaben gemacht werden',
                    'Missbrauch der Plattform vorliegt',
                  ],
                ),

                const _LegalSection(
                  number: '12.',
                  title: 'Schlussbestimmungen',
                  paragraphs: [
                    'Es gilt deutsches Recht.',
                    'Gerichtsstand ist, soweit zulässig, der Sitz des Betreibers von Capacify.',
                  ],
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

// ─── REUSABLE LEGAL WIDGETS ────────────────────────────

class _LegalTitle extends StatelessWidget {
  final String text;

  const _LegalTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: c.textPrimary,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String number;
  final String title;
  final List<String> paragraphs;
  final List<String>? bulletPoints;

  const _LegalSection({
    required this.number,
    required this.title,
    required this.paragraphs,
    this.bulletPoints,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Paragraphs
                ...paragraphs.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),

                // Bullet points
                if (bulletPoints != null)
                  ...bulletPoints!.map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 6,
                        left: 8,
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin:
                                const EdgeInsets.only(
                              top: 7,
                              right: 10,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              point,
                              style: TextStyle(
                                fontSize: 14,
                                color: c.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
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