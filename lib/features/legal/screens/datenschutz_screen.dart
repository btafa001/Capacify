import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DatenschutzScreen extends StatelessWidget {
  const DatenschutzScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          'Datenschutzerklärung',
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
                // Draft notice
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(
                      bottom: 32),
                  decoration: BoxDecoration(
                    color: AppColors.accent
                        .withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent
                          .withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.accent,
                        size: 16,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Entwurf – Vor dem Launch durch einen deutschen IT-Rechtsanwalt prüfen lassen.',
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

                Text(
                  'Datenschutzerklärung',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gemäß DSGVO (Datenschutz-Grundverordnung)',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                _DPlaceholder(
                  title: 'Verantwortlicher',
                  fields: const [
                    'Unternehmensname: [Eintragen]',
                    'Adresse: [Eintragen]',
                    'E-Mail: [Eintragen]',
                  ],
                ),

                _DSection(
                  number: '§1',
                  title: 'Erhobene Daten',
                  paragraphs: const [
                    'Im Rahmen der Nutzung können folgende Daten verarbeitet werden:',
                  ],
                  bulletPoints: const [
                    'Firmenname',
                    'Ansprechpartner',
                    'E-Mail-Adresse',
                    'Telefonnummer',
                    'Profilinformationen',
                    'Nachrichten',
                    'Anfragen und Angebote',
                    'Log-Daten',
                    'IP-Adresse',
                  ],
                ),

                _DSection(
                  number: '§2',
                  title: 'Zweck der Verarbeitung',
                  paragraphs: const [
                    'Die Verarbeitung erfolgt zur:',
                  ],
                  bulletPoints: const [
                    'Bereitstellung der Plattform',
                    'Authentifizierung',
                    'Kommunikation zwischen Unternehmen',
                    'Betrugsprävention',
                    'Verbesserung der Plattform',
                  ],
                ),

                _DSection(
                  number: '§3',
                  title: 'Rechtsgrundlagen',
                  paragraphs: const [
                    'Die Verarbeitung erfolgt gemäß Art. 6 DSGVO auf folgenden Rechtsgrundlagen:',
                  ],
                  bulletPoints: const [
                    'Art. 6 Abs. 1 lit. b DSGVO – Vertragserfüllung',
                    'Art. 6 Abs. 1 lit. c DSGVO – Rechtliche Verpflichtung',
                    'Art. 6 Abs. 1 lit. f DSGVO – Berechtigte Interessen',
                  ],
                ),

                _DSection(
                  number: '§4',
                  title: 'Weitergabe von Daten',
                  paragraphs: const [
                    'Daten werden nur weitergegeben, soweit dies:',
                  ],
                  bulletPoints: const [
                    'zur Vertragserfüllung erforderlich ist',
                    'gesetzlich vorgeschrieben ist',
                    'vom Nutzer veranlasst wird',
                  ],
                ),

                _DSection(
                  number: '§5',
                  title: 'Speicherdauer',
                  paragraphs: const [
                    'Personenbezogene Daten werden nur so lange gespeichert, wie dies für die Bereitstellung der Plattform erforderlich ist.',
                    'Nach Ablauf der gesetzlichen Aufbewahrungsfristen werden die Daten gelöscht oder gesperrt.',
                  ],
                ),

                _DSection(
                  number: '§6',
                  title: 'Rechte der Nutzer',
                  paragraphs: const [
                    'Nutzer haben insbesondere das Recht auf:',
                  ],
                  bulletPoints: const [
                    'Auskunft (Art. 15 DSGVO)',
                    'Berichtigung (Art. 16 DSGVO)',
                    'Löschung (Art. 17 DSGVO)',
                    'Einschränkung der Verarbeitung (Art. 18 DSGVO)',
                    'Datenübertragbarkeit (Art. 20 DSGVO)',
                    'Widerspruch (Art. 21 DSGVO)',
                  ],
                ),

                _DSection(
                  number: '§7',
                  title: 'Sicherheit',
                  paragraphs: const [
                    'Capacify setzt technische und organisatorische Maßnahmen ein, um Daten vor Verlust, Missbrauch und unbefugtem Zugriff zu schützen.',
                    'Die Datenübertragung erfolgt verschlüsselt (TLS/SSL). Die Verarbeitung erfolgt auf Servern innerhalb der Europäischen Union.',
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

// ── Widgets private to this file ──

class _DPlaceholder extends StatelessWidget {
  final String title;
  final List<String> fields;

  const _DPlaceholder({
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

class _DSection extends StatelessWidget {
  final String number;
  final String title;
  final List<String> paragraphs;
  final List<String>? bulletPoints;

  const _DSection({
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.primary
                        .withOpacity(0.2),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                ...paragraphs.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: 8),
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
                            decoration:
                                const BoxDecoration(
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