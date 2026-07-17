import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../constants/app_constants.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  bool get isEn => locale.languageCode == 'en';
  // Falls back to the other language if the chosen one is accidentally empty,
  // so a forgotten translation degrades to the other locale instead of a blank.
  String _t(String de, String en) {
    if (isEn) return en.isNotEmpty ? en : de;
    return de.isNotEmpty ? de : en;
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('de'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // ── Shared ──────────────────────────────────────────────────────────────────
  String get liveLabel       => 'LIVE';
  String get verifiedLabel   => _t('VERIFIZIERT', 'VERIFIED');
  String get availableLabel  => _t('VERFÜGBAR', 'AVAILABLE');
  String get wantedLabel     => _t('GESUCHT', 'NEEDED');
  String get offerLabel      => _t('ANGEBOT', 'OFFER');
  String get needLabel       => _t('GESUCH', 'INQUIRY');
  String get cancel          => _t('Abbrechen', 'Cancel');
  String get required        => _t('Pflichtfeld', 'Required');
  String get signOut         => _t('Abmelden', 'Sign out');
  String get expired         => _t('Abgelaufen', 'Expired');
  String get persons         => _t('Personen', 'persons');
  // Post-creation flow: leads with team framing rather than a raw headcount.
  String get teamSizeLabel   => _t('Teamgröße', 'Team size');
  String get callTooltip     => _t('Anrufen', 'Call');
  // Perishability + freshness (feed card).
  String daysLeftLabel(int n) => n <= 1
      ? _t('nur noch heute', 'today only')
      : _t('noch $n Tage', '$n days left');
  String get confirmedTodayLabel => _t('Heute bestätigt', 'Confirmed today');
  String interestedCountLabel(int n) => n == 1 ? _t('1 interessiert', '1 interested') : _t('$n interessiert', '$n interested');
  // Effortless posting: repost + one-tap availability reconfirm.
  String get repostAction        => _t('Erneut posten', 'Repost');
  String get reconfirmAction     => _t('Noch frei? Bestätigen', 'Still free? Confirm');
  String get reconfirmedSnackbar => _t('Verfügbarkeit bestätigt – für eine weitere Woche', 'Availability confirmed – for another week');
  // Company trust signals (member since / last active).
  String memberSinceLabel(int year) => _t('Mitglied seit $year', 'Member since $year');
  String responseTimeLabel(int hours) {
    if (hours <= 1) {
      return _t('Antwortet meist in unter 1 Std.', 'Usually responds within 1h');
    }
    if (hours < 24) {
      return _t('Antwortet meist in ~$hours Std.', 'Usually responds in ~${hours}h');
    }
    final days = (hours / 24).ceil();
    return days <= 1
        ? _t('Antwortet meist in ~1 Tag', 'Usually responds in ~1 day')
        : _t('Antwortet meist in ~$days Tagen', 'Usually responds in ~$days days');
  }
  String get activeTodayLabel     => _t('Heute aktiv', 'Active today');
  String get activeYesterdayLabel => _t('Gestern aktiv', 'Active yesterday');
  String activeDaysAgoLabel(int n) => _t('Vor $n Tagen aktiv', 'Active $n days ago');
  // Landing proof-of-life ticker (real counts).
  String pulseActiveCapacities(int n) => _t('$n Kapazitäten aktiv', '$n active capacities');
  String pulseCompanies(int n) => _t('$n Firmen dabei', '$n companies onboard');
  String foundingMemberPulseLabel(int floor) => _t(
      'Gründungsmitglieder gesucht — sei einer der ersten $floor Hamburger Betriebe',
      'Founding members wanted — be one of the first $floor Hamburg firms');
  // Saved searches + profile-match relevance.
  String get saveSearchLabel     => _t('Speichern', 'Save');
  String get searchSavedSnackbar => _t('Suche gespeichert', 'Search saved');
  String get savedAnyTradesLabel => _t('Alle Gewerke', 'All trades');
  String get matchesProfileBadge => _t('Passt zu Ihrem Profil', 'Matches your profile');
  // ── Milestones (wow moments — professional, fire once) ──────────────────────
  String get msProfileTitle    => _t('Profil vollständig', 'Profile complete');
  String get msProfileBody     => _t('Ihr Unternehmen ist jetzt sichtbar und wirkt vertrauenswürdiger.', 'Your company is now visible and looks more trustworthy.');
  String get msFirstPostTitle  => _t('Ihre erste Kapazität ist live', 'Your first capacity is live');
  String get msFirstPostBody   => _t('Bauunternehmen in Hamburg können sie ab jetzt entdecken.', 'Construction firms in Hamburg can discover it now.');
  String get msFirstMsgTitle   => _t('Erste Nachricht gesendet', 'First message sent');
  String get msFirstMsgBody    => _t('Sobald das Unternehmen annimmt, öffnet sich der Chat.', 'As soon as the company accepts, the chat opens.');
  String get msFirstConnTitle  => _t('Erste Verbindung', 'First connection');
  String get msFirstConnBody   => _t('Sie sind jetzt verbunden – viel Erfolg bei der Zusammenarbeit.', 'You are now connected — good luck with the collaboration.');
  String get msFirstCollabTitle => _t('Erste Zusammenarbeit', 'First collaboration');
  String get msFirstCollabBody  => _t('Beide Seiten haben bestätigt – ein starkes Vertrauenssignal auf Ihrem Profil.', 'Both sides confirmed — a strong trust signal on your profile.');
  // Collaboration confirmation (on a granted connection, shown in the chat).
  String get collabPromptTitle     => _t('Haben Sie zusammengearbeitet?', 'Did you work together?');
  String get collabPromptBody      => _t('Bestätigen Sie die Zusammenarbeit – zählt für das Vertrauen beider Firmen.', 'Confirm the collaboration — it counts toward both companies\' trust.');
  String get collabConfirmButton   => _t('Zusammenarbeit bestätigen', 'Confirm collaboration');
  String get collabWaitingPartner  => _t('Von Ihnen bestätigt – warten auf den Partner', 'Confirmed by you — waiting for the partner');
  String get collabConfirmedBoth   => _t('Zusammenarbeit bestätigt', 'Collaboration confirmed');
  String get collabConfirmSnackbar => _t('Danke! Ihre Bestätigung wurde gespeichert.', 'Thanks — your confirmation was saved.');
  String get collabOutcomeDialogTitle => _t('Wie ist es gelaufen?', 'How did it go?');
  String get collabOutcomeDialogBody => _t(
      'Optional — hilft uns, passende Kapazitäten künftig noch besser zu vermitteln.',
      'Optional — helps us match capacity even better in future.');
  String get collabActualCrewSizeLabel => _t('Tatsächliche Anzahl Personen', 'Actual number of people');
  String get collabActualDurationLabel => _t('Dauer in Tagen (optional)', 'Duration in days (optional)');
  String collabCountLabel(int n)   => n == 1 ? _t('1 Zusammenarbeit', '1 collaboration') : _t('$n Zusammenarbeiten', '$n collaborations');
  String collabRepeatLabel(int n)  => _t('$n mit Wiederkehr', '$n repeat');
  // In-app notification center (bell).
  String get notificationsTitle        => _t('Benachrichtigungen', 'Notifications');
  String get notificationsEmpty        => _t('Keine neuen Benachrichtigungen.', 'No new notifications.');
  String get notificationsVermittlungen => _t('Vermittlungen', 'Connections');
  String get notificationsMessages     => _t('Nachrichten', 'Messages');
  String get notificationsMatches      => _t('Neue Kapazitäten für Sie', 'New capacities for you');
  // Admin-only notification section (#9) — verification/flag/rating events.
  String get notificationsAdminEvents  => _t('Admin', 'Admin');
  String notificationVerificationSubmitted(String name) =>
      _t('$name hat eine Verifizierung beantragt', '$name submitted a verification request');
  String notificationContentFlaggedCompany(String name) =>
      _t('$name wurde gemeldet', '$name was flagged');
  String get notificationContentFlaggedCapacity =>
      _t('Ein Beitrag wurde gemeldet', 'A posting was flagged');
  String notificationRatingSubmitted(String name) =>
      _t('Neue Bewertung für $name wartet auf Freigabe', 'A new rating for $name is awaiting approval');
  String get reportUser                => _t('Nutzer melden', 'Report user');
  // ── Pricing / plans (H6) ──────────────────────────────────────────────────
  String get pricingTitle          => _t('Vermittlungen & Tarife', 'Connections & plans');
  String get pricingEarlyAccessBadge => _t('Early Access', 'Early Access');
  String pricingEarlyAccessBody(int n) =>
      _t('Sie erhalten aktuell $n Vermittlungen pro Monat – kostenlos, für alle Funktionen.',
         'You currently get $n connections per month — free, with every feature unlocked.');
  String get pricingPlansHeader    => _t('TARIFE (BALD)', 'PLANS (SOON)');
  String get planCurrentLabel      => _t('Aktiv', 'Active');
  String get planComingSoon        => _t('Bald', 'Soon');
  String get planFreeName          => _t('Free', 'Free');
  String planFreeQuota(int n)      => _t('$n Vermittlungen / Monat', '$n connections / month');
  String get planFreePrice         => _t('0 €', '€0');
  String get planFreeDesc          => _t('Zum Ausprobieren – für gelegentliche Anfragen.', 'To get started — for the occasional request.');
  String get planProName           => _t('Pro', 'Pro');
  String planProQuota(int n)       => _t('$n Vermittlungen / Monat', '$n connections / month');
  String get planProPrice          => _t('Bald', 'Soon');
  String get planProDesc           => _t('Für Firmen, die regelmäßig Kapazität suchen oder anbieten.', 'For firms that regularly seek or offer capacity.');
  String get planPremiumName       => _t('Premium', 'Premium');
  String get planPremiumQuota      => _t('Unbegrenzte Vermittlungen', 'Unlimited connections');
  String get planPremiumPrice      => _t('Bald', 'Soon');
  String get planPremiumDesc       => _t('Für Vielnutzer und Teams – keine Limits.', 'For power users and teams — no limits.');
  String get pricingHowCreditsWork => _t(
      'Eine Vermittlung wird verbraucht, sobald Sie den Kontakt eines Anbieters freischalten. Nicht genutzte Vermittlungen verfallen am Monatsende.',
      'One connection is used when you unlock a provider\'s contact. Unused connections expire at the end of the month.');
  String get viewPlansLink         => _t('Tarife ansehen', 'View plans');
  // Automatic VIES VAT verification (server-side Cloud Function).
  String get verifyNowVies    => _t('Automatisch prüfen (VIES)', 'Verify automatically (VIES)');
  String get verifyNeedVatFirst => _t('Bitte zuerst die USt-IdNr. speichern.', 'Please save your VAT number first.');
  String get verifySuccessVies => _t('USt-IdNr. bestätigt ✓ — zur Freigabe eingereicht.', 'VAT confirmed ✓ — submitted for approval.');
  String get verifyInvalidVies => _t('USt-IdNr. konnte nicht bestätigt werden. Manuelle Prüfung folgt.', 'VAT could not be confirmed. Manual review will follow.');
  String get viesConfirmed => _t('VIES: USt-IdNr. gültig', 'VIES: VAT valid');
  String viesConfirmedWithName(String name) => _t('VIES: gültig — registriert auf „$name"', 'VIES: valid — registered to "$name"');
  String notificationUnlockedBy(String name) =>
      _t('$name hat Ihre Anzeige freigeschaltet', '$name unlocked your listing');
  String get completeProfileToPostTitle =>
      _t('Profil vervollständigen', 'Complete your profile');
  String get completeProfileToPostBody => _t(
      'Bevor Sie eine Kapazität veröffentlichen, vervollständigen Sie bitte Ihr Firmenprofil (Telefon, Adresse, Gewerke und eine kurze Beschreibung). So bleibt der Marktplatz vertrauenswürdig – auch wenn Ihre Anzeige anonym erscheint.',
      'Before posting a capacity, please complete your company profile (phone, address, trades and a short description). This keeps the marketplace trustworthy — even though your post stays anonymous.');
  String get completeProfileToPostCta => _t('Zum Profil', 'Go to profile');
  // Specific "which field(s) exactly" messaging — replaces the generic
  // completeProfileToPostBody/completeProfileToRequestNotice at the actual
  // post/contact gate call sites, so a company isn't left guessing what's
  // still missing (see CompanyModel.missingCompletenessFieldsLabel).
  String completeProfileMissingFieldsBody(String fields) => _t(
      'Bevor Sie veröffentlichen oder kontaktieren können, ergänzen Sie bitte: $fields.',
      'Before you can post or contact, please add: $fields.');
  String get missingFieldDescription   => _t('Beschreibung', 'Description');
  String get missingFieldPhoneCompany  => _t('Telefonnummer', 'Phone number');
  String get missingFieldAddress       => _t('Adresse', 'Address');
  String get missingFieldTrades        => _t('Gewerk', 'Trade');
  String get days            => _t('Tage', 'days');
  String get active          => _t('aktiv', 'active');

  // ── Landing navbar ──────────────────────────────────────────────────────────
  String get navAbout           => _t('Über uns', 'About');
  String get navLogin           => 'Login';
  String get navStartFree       => _t('Kostenlos starten', 'Get started');
  String get navStartFreeMobile => 'Start';

  // ── Hero ────────────────────────────────────────────────────────────────────
  String get heroLiveBadge   => _t('Neue Kapazitäten · live aktualisiert', 'New capacity posts · updated live');
  // Eyebrow label inside the hero's card-grid chrome frame — frames the 4
  // example cards as "a live look at the marketplace" rather than a floating
  // mockup. Deliberately no numbers here (see _MarketPulseRow's comment).
  String get heroFrameLabel  => _t('KAPAZITÄTS-MARKTPLATZ', 'CAPACITY MARKETPLACE');
  String get heroTitle       => _t('Wer ist heute\n', 'Who is available\n');
  String get heroHighlight   => _t('verfügbar', 'today');
  String get heroSubtitle    => _t(
    'Capacify verbindet Bauunternehmen\nund Nachunternehmer in Echtzeit.',
    'Capacify connects construction companies\nand subcontractors in real time.',
  );
  String get heroSubtitleMobile => _t(
    'Capacify verbindet Bauunternehmen und Nachunternehmer in Echtzeit.',
    'Capacify connects construction companies and subcontractors in real time.',
  );
  String get heroCtaRegister => _t('Kostenlos registrieren', 'Register for free');
  String get heroStatLocation => _t('Hamburg', 'Hamburg');
  String heroStatTrades(int n) => _t('$n Gewerke', '$n trades');

  // ── Preview card demo data ───────────────────────────────────────────────────
  String get card1Title  => _t('3 Elektriker verfügbar',   '3 Electricians available');
  String get card2Title  => _t('2 Dachdecker gesucht',     '2 Roofers needed');
  String get card3Title  => _t('5 Trockenbauer frei',      '5 Drywallers available');
  String get card4Title  => _t('4 Installateure gesucht',  '4 Installers needed');
  String get card1Avail  => _t('Ab nächster Woche',        'From next week');
  String get card2Avail  => _t('Start morgen',             'Starting tomorrow');
  String get card3Avail  => _t('Sofort verfügbar',         'Available now');
  String get card4Avail  => _t('3 Wochen Einsatz',         '3 weeks assignment');
  String ago(int n)      => isEn ? '${n} min ago' : 'vor ${n} min';
  String get persPeriod  => _t('Pers.', 'pers.');

  // ── How it works ─────────────────────────────────────────────────────────────
  String get howTitle    => _t('Wie es funktioniert',                    'How it works');
  String get howSubtitle => _t('In drei Schritten zur ersten Verbindung.', 'Three steps to your first connection.');
  // Visible is the default visibility mode (see CapacityVisibilityMode) —
  // "anonymously" overstated what browsing actually looks like for most
  // posts, which show identity directly. Anonymous mode is now surfaced
  // separately, as an opt-in choice, in the Unlock Showcase section below.
  String get step1Title  => _t('Kapazitäten entdecken',                   'Discover capacity');
  // Shortened to a scannable phrase, not a full sentence — matches the
  // punchier voice used elsewhere on the page (badges, CTAs).
  String get step1Desc   => _t('Filtern nach Gewerk, Ort und Datum.', 'Filter by trade, location and date.');
  String get step2Title  => _t('Nachricht senden',                       'Send a message');
  String get step2Desc   => _t('Kostenlos – ohne Kredite, ohne Bezahlung.', 'Free — no credits, no payment.');
  String get step3Title  => _t('Verbinden & zusammenarbeiten',           'Connect & collaborate');
  // Instant-grant (visible/discreet, the default) vs. Accept-gated
  // (anonymous, opt-in) — see ContactRequestService.requestContact. Only the
  // latter waits on the poster's click.
  String get step3Desc   => _t(
    'Meist sofort freigeschaltet. Bei anonymen Anzeigen erst nach Bestätigung.',
    'Usually instant. Anonymous posts need a quick accept first.',
  );

  // ── Landing: anonymous mode showcase (opt-in, not the default) ─────────────
  String get unlockShowcaseTitle => _t('Lieber anonym bleiben? Sie entscheiden.', 'Prefer to stay anonymous? You decide.');
  String get unlockShowcaseSubtitle => _t(
    'Standardmäßig zeigen Ihre Anzeigen Firmenname und Logo. Wählen Sie stattdessen den Anonym-Modus, sehen Interessenten nur die Eckdaten – bis Sie eine Anfrage annehmen.',
    'By default your posts show your company name and logo. Choose Anonymous mode instead, and interested companies see only the basics — until you accept a request.');
  String get showcaseAnonBadge => _t('FIRMA VERBORGEN', 'COMPANY HIDDEN');
  // "Connected" — the free message-first outcome (was "UNLOCKED", the old paid reveal).
  String get showcaseUnlockedBadge => _t('VERBUNDEN', 'CONNECTED');
  // The middle step is now sending a free message (was the "1 Vermittlung" credit).
  String get showcaseVermittlungPill => _t('Nachricht senden', 'Send message');
  String get showcaseHiddenName => _t('Firmenname verborgen', 'Company name hidden');
  String get showcaseDemoTitle => _t('Dachdecker-Kolonne verfügbar', 'Roofer crew available');
  String get showcaseDemoRating => _t('4,7 · Verifiziert', '4.7 · Verified');

  // ── For who section ──────────────────────────────────────────────────────────
  String get forWhoTitle       => _t('Für wen ist Capacify?',                                  'Who is Capacify for?');
  String get forWhoSubtitle    => _t('Zwei Seiten, ein Ziel: Kapazitäten sinnvoll nutzen.',     'Two sides, one goal: putting capacity to good use.');
  String get forWhoOfferTag    => _t('HABEN KAPAZITÄT',  'HAVE CAPACITY');
  String get forWhoOfferTitle  => _t('Team gerade frei?', 'Team free right now?');
  String get forWhoOfferDesc   => _t(
    'Veröffentlichen Sie, welche Mitarbeiter oder Maschinen verfügbar sind — und für wie lange.',
    'Post which workers or machines are available — and for how long.',
  );
  String get forWhoOfferPoint1 => _t('In unter 2 Minuten online',          'Live in under 2 minutes');
  String get forWhoOfferPoint2 => _t('Sichtbar für passende Suchende',     'Visible to matching searchers');
  String get forWhoNeedTag     => _t('SUCHEN KAPAZITÄT', 'NEED CAPACITY');
  String get forWhoNeedTitle   => _t('Kurzfristig Unterstützung nötig?',   'Need support on short notice?');
  String get forWhoNeedDesc    => _t(
    'Durchsuchen Sie freie Kapazitäten nach Gewerk, Stadtteil und Verfügbarkeit.',
    'Browse free capacity by trade, district, and availability.',
  );
  String get forWhoNeedPoint1  => _t('Filter nach Gewerk & Ort',           'Filter by trade & location');
  String get forWhoNeedPoint2  => _t('Direkter Kontakt, keine Wartezeit',  'Direct contact, no waiting');

  // ── Network section ──────────────────────────────────────────────────────────
  String get networkTitle      => _t('Fokussiert auf Hamburg',                                              'Focused on Hamburg');
  String get networkSubtitle   => _t('Alle 15 Stadtteile abgedeckt — von Altona bis Bergedorf.',             'All 15 districts covered — from Altona to Bergedorf.');
  String get networkFactDistricts => _t('Stadtteile', 'Districts');
  String get networkFactTrades    => _t('Gewerke', 'Trades');
  String get networkFactLive      => _t('Echtzeit-Feed', 'Real-time feed');
  String get networkFactLiveValue => _t('Live', 'Live');

  // ── Trust section ────────────────────────────────────────────────────────────
  String get trustTitle    => _t('Vertrauen & Sicherheit',              'Trust & Safety');
  // Verification is opt-in (VAT check requested from the profile page), not
  // gated at registration — "nur verifizierte" overstated it as universal.
  String get trustSubtitle => _t('Geprüfte Firmenprofile, transparente Bewertungen – und die Wahl, ob Sie sichtbar oder anonym posten.', 'Verified company profiles, transparent ratings — and your choice to post visibly or anonymously.');
  String get trust1Title   => _t('Verifiziert',    'Verified');
  String get trust1Desc    => _t('Geprüfte Unternehmensprofile',            'Verified company profiles');
  String get trust2Title   => _t('Bewertet',       'Rated');
  String get trust2Desc    => _t('Transparente Ratings nach jedem Auftrag', 'Transparent ratings after every job');
  String get trust3Title   => _t('Direkter Kontakt', 'Direct contact');
  String get trust3Desc    => _t('Telefon & E-Mail sichtbar — kein Vermittler', 'Phone & email visible — no middleman');
  String get trust4Title   => 'GDPR';
  String get trust4Desc    => _t('Datenschutzkonform nach deutschem Recht', 'Data protection compliant under German law');

  // ── Final CTA ────────────────────────────────────────────────────────────────
  String get ctaBadge         => _t('Kostenlos · Kein Abo · Sofort starten', 'Free · No subscription · Start now');
  String get ctaTitle         => _t('Werden Sie Teil\ndes Netzwerks.',        'Become part\nof the network.');
  String get ctaSubtitle      => _t(
    'Nutzen Sie freie Kapazitäten besser oder finden Sie kurzfristig Unterstützung für Ihr nächstes Projekt.',
    'Make better use of free capacities or find short-term support for your next project.',
  );
  String get ctaAlreadyMember => _t('Bereits Mitglied? Login', 'Already a member? Login');

  // ── Footer ───────────────────────────────────────────────────────────────────
  String get footerTagline    => _t('Kapazitäten finden. Projekte sichern.', 'Find capacities. Secure projects.');
  String get footerDisclaimer => _t(
    'Capacify vermittelt Kontakte zwischen unabhängigen Unternehmen und wird nicht Vertragspartei der geschlossenen Vereinbarungen.',
    'Capacify connects independent companies and does not become a party to the agreements made.',
  );
  String get footerAGB        => _t('AGB',          'Terms');
  String get footerPrivacy    => _t('Datenschutz',  'Privacy');
  String get footerImprint    => _t('Impressum',    'Imprint');
  String get footerContact    => _t('Kontakt',      'Contact');

  // ── Cookie / analytics consent (GDPR/TTDSG) ──────────────────────────────────
  String get consentBody => _t(
      'Wir verwenden Cookies und Analyse-Tools, um Capacify zu verbessern. Analyse-Cookies werden nur mit Ihrer Einwilligung gesetzt. Sie können Ihre Auswahl jederzeit in den Einstellungen ändern.',
      'We use cookies and analytics to improve Capacify. Analytics cookies are only set with your consent. You can change your choice anytime in Settings.');
  String get consentLearnMore => _t('Mehr erfahren', 'Learn more');
  String get consentAccept    => _t('Akzeptieren', 'Accept');
  String get consentDecline   => _t('Ablehnen', 'Decline');
  String get consentSettingsTitle => _t('Analyse & Cookies', 'Analytics & cookies');
  String get consentSettingsSubtitle =>
      _t('Anonyme Nutzungsstatistik erlauben', 'Allow anonymous usage analytics');
  String get analyticsOnSubtitle  => _t('Aktiviert — Sie können jederzeit widerrufen', 'On — you can revoke anytime');
  String get analyticsOffSubtitle => _t('Deaktiviert — keine Analyse-Cookies', 'Off — no analytics cookies');

  // ── Privacy & data (GDPR export / erasure) ───────────────────────────────────
  String get privacyDataSectionCaps => _t('DATENSCHUTZ & DATEN', 'PRIVACY & DATA');
  String get privacyLegalSectionCaps => _t('DATENSCHUTZ & RECHTLICHES', 'PRIVACY & LEGAL');
  String get exportDataTitle    => _t('Meine Daten exportieren', 'Export my data');
  String get exportDataSubtitle => _t('Alle zu Ihrem Konto gespeicherten Daten als JSON herunterladen', 'Download everything stored about your account as JSON');
  String get exportDataStarted  => _t('Download gestartet', 'Download started');
  String get deleteAccountTitle    => _t('Konto löschen', 'Delete account');
  String get deleteAccountSubtitle => _t('Konto und personenbezogene Daten dauerhaft entfernen', 'Permanently remove your account and personal data');
  String get deleteAccountConfirmTitle => _t('Konto wirklich löschen?', 'Delete account?');
  String get deleteAccountConfirmBody => _t(
      'Dies entfernt Ihr Konto und anonymisiert Ihr Firmenprofil und Ihre Anzeigen dauerhaft. Bereits abgeschlossene Vermittlungen bleiben aus rechtlichen Gründen anonymisiert erhalten. Dieser Schritt kann nicht rückgängig gemacht werden.',
      'This removes your account and permanently anonymises your company profile and posts. Completed connections are kept in anonymised form for legal reasons. This cannot be undone.');
  String get deleteAccountConfirmCta => _t('Endgültig löschen', 'Delete permanently');
  String get deleteAccountReauthNeeded => _t(
      'Bitte melden Sie sich zur Sicherheit erneut an und versuchen Sie es dann noch einmal.',
      'For security, please sign in again and then retry.');
  String get genericErrorRetry => _t('Ein Fehler ist aufgetreten. Bitte erneut versuchen.', 'Something went wrong. Please try again.');

  // ── Social sign-in ───────────────────────────────────────────────────────────
  String get orDivider           => _t('oder', 'or');
  String get continueWithGoogle  => _t('Weiter mit Google', 'Continue with Google');
  String get continueWithApple   => _t('Weiter mit Apple', 'Continue with Apple');

  // ── Login ────────────────────────────────────────────────────────────────────
  String get loginTitle       => _t('Anmelden',          'Sign in');
  String get loginWelcome     => _t('Willkommen zurück.', 'Welcome back.');
  String get loginSloganLine1 => _t('Kapazitäten finden.', 'Find capacities.');
  String get loginSloganLine2 => _t('Projekte sichern.',   'Secure projects.');
  String get loginSloganSub   => _t('Freie Teams sichtbar machen.', 'Make free teams visible.');
  String get loginQuote1      => _t('Jede Lücke kostet.', 'Every gap costs you.');
  String get loginQuote2      => _t('Schließen Sie sie in Stunden – nicht Wochen.', 'Close it in hours — not weeks.');
  String get loginLiveBadge   => 'LIVE · $kServiceRegion · $kServiceRadiusKm km Radius';
  String get emailLabel       => 'E-Mail';
  String get passwordLabel    => _t('Passwort',           'Password');
  String get forgotPassword   => _t('Passwort vergessen?', 'Forgot password?');
  String get loginButton      => _t('ANMELDEN',  'SIGN IN');
  String get noAccount        => _t('Noch kein Konto? ',  'No account? ');
  String get registerLink     => _t('Registrieren',       'Register');
  String get invalidEmail     => _t('Ungültige E-Mail',   'Invalid email');

  // ── Register ─────────────────────────────────────────────────────────────────
  String get registerTitle    => _t('Konto erstellen',               'Create account');
  String get registerSubtitle => _t('Werden Sie Teil der Kapazitätsbörse.', 'Join the capacity exchange.');
  String get registerQuickNote => _t('Nur das Nötigste — den Rest Ihres Unternehmensprofils füllen Sie danach aus.', 'Just the essentials — you can fill in the rest of your company profile afterward.');
  String get sectionPersonal  => _t('PERSÖNLICHE DATEN',  'PERSONAL DATA');
  String get firstNameLabel   => _t('Vorname *',          'First name *');
  String get firstNameHint    => _t('Max',                'John');
  String get lastNameLabel    => _t('Nachname *',         'Last name *');
  String get lastNameHint     => _t('Mustermann',         'Smith');
  String get emailHint        => 'ihre@email.de';
  String get passwordHint     => _t('Mindestens 8 Zeichen', 'At least 8 characters');
  String get passwordWeak     => _t('Schwach',  'Weak');
  String get passwordMedium   => _t('Mittel',   'Medium');
  String get passwordStrong   => _t('Stark',    'Strong');
  String get req8Chars        => _t('Mindestens 8 Zeichen', 'At least 8 characters');
  String get req1Upper        => _t('Ein Großbuchstabe',    'One uppercase letter');
  String get req1Number       => _t('Eine Zahl',            'One number');
  String get sectionCompany   => _t('IHR UNTERNEHMEN',   'YOUR COMPANY');
  String get companyNameLabel => _t('Unternehmensname *', 'Company name *');
  String get companyNameHint  => _t('Mustermann GmbH',   'Smith Ltd.');
  String get tradeLabel       => _t('Gewerk *',           'Trade *');
  String get cityLabel        => _t('Stadt *',            'City *');
  // Required on the COMPANY profile form specifically — phone/address gate
  // isProfileComplete there, but the shared phoneLabel/addressLabel getters
  // are also used by admin_onboarding_screen.dart and other non-required
  // contexts, so those stay untouched and these two are scoped to that one
  // call site each.
  String get companyPhoneRequiredLabel   => _t('Telefon *', 'Phone *');
  String get companyAddressRequiredLabel => _t('Adresse *', 'Address *');
  String get cityHint         => 'Hamburg';
  String get phoneLabel       => _t('Telefon',            'Phone');
  String get phoneHint        => '+49 40 123456';
  String get companyEmailLabel => _t('Unternehmens-E-Mail *', 'Company email *');
  String get companyEmailHint  => _t('info@mustermann-gmbh.de', 'info@company.com');
  String get websiteLabel     => 'Website';
  String get sectionVerify    => _t('VERIFIZIERUNG', 'VERIFICATION');
  String get verifiedBadgeLabel => _t('Ihr Unternehmen ist verifiziert', 'Your company is verified');
  String get vatLabel         => _t('Umsatzsteuer-ID (USt-IdNr.)', 'VAT number');
  String get vatHint          => 'DE123456789';
  String get vatError         => _t('Format: DE + 9 Ziffern (z.B. DE123456789)', 'Format: DE + 9 digits (e.g. DE123456789)');
  String get verifyHowTitle   => _t('Wie die Verifizierung funktioniert', 'How verification works');
  String get verifySteps      => _t(
    '1. Geben Sie Ihre USt-IdNr. ein\n'
    '2. Senden Sie eine Kopie Ihres Steuerdokuments an: info@capacify.de\n'
    '3. Nach Prüfung erhalten Sie das ✓ VERIFIZIERT Badge auf Ihrem Profil',
    '1. Enter your VAT number\n'
    '2. Send a copy of your tax document to: info@capacify.de\n'
    '3. After review, you will receive the ✓ VERIFIED badge on your profile',
  );
  String get consentPrefix    => _t(
    'Ich handle im Namen eines Unternehmens und akzeptiere die ',
    'I act on behalf of a company and accept the ',
  );
  String get consentMiddle    => _t(' sowie die ', ' and the ');
  String get consentSuffix    => '.';
  String get consentError     => _t(
    'Bitte stimmen Sie den AGB und der Datenschutzerklärung zu.',
    'Please accept the terms and privacy policy.',
  );
  String get weakPwError      => _t(
    'Bitte wählen Sie ein stärkeres Passwort.',
    'Please choose a stronger password.',
  );
  String get registerButton   => _t('KOSTENLOS REGISTRIEREN', 'REGISTER FOR FREE');
  String get registerDisclaimer => _t(
    'Capacify stellt ausschließlich eine technische Plattform zur Vernetzung unabhängiger Unternehmen bereit. Verträge kommen ausschließlich zwischen den beteiligten Unternehmen zustande.',
    'Capacify provides exclusively a technical platform for connecting independent companies. Contracts are concluded exclusively between the participating companies.',
  );
  String get alreadyRegistered => _t('Bereits registriert? ', 'Already registered? ');
  String get toLogin           => _t('Zur Anmeldung', 'Sign in');
  String get enterEmail        => _t('Bitte E-Mail eingeben',   'Please enter email');
  String get invalidEmailAddr  => _t('Ungültige E-Mail-Adresse', 'Invalid email address');
  String get disposableEmailError => _t(
      'Bitte eine dauerhafte geschäftliche E-Mail-Adresse verwenden (keine Wegwerf-Adresse).',
      'Please use a permanent business email address (no disposable/temp-mail addresses).');
  String get verifyEmailBannerBody => _t(
      'Bitte bestätigen Sie Ihre E-Mail-Adresse — erst danach können Sie Kapazitäten posten oder Firmen kontaktieren.',
      'Please verify your email address — you need to before you can post capacities or contact companies.');
  String get resendVerificationButton => _t('E-Mail erneut senden', 'Resend email');
  String get iveVerifiedButton        => _t('Ich habe bestätigt', "I've verified");
  String get verificationEmailResent  => _t('E-Mail wurde erneut gesendet.', 'Verification email sent again.');
  String get invalidPhoneNumber => _t('Ungültige Telefonnummer', 'Invalid phone number');
  String get invalidPostalCode  => _t('Ungültige Postleitzahl (5 Ziffern)', 'Invalid postal code (5 digits)');
  String get enterPassword     => _t('Bitte Passwort eingeben',  'Please enter password');
  String get min8Chars         => _t('Mindestens 8 Zeichen',     'At least 8 characters');
  String get agbLabel          => _t('AGB', 'Terms');
  String get privacyLabel      => _t('Datenschutzerklärung', 'Privacy Policy');

  // ── Dashboard sidebar ────────────────────────────────────────────────────────
  String get navLiveFeed     => 'Live Feed';
  String get navCompanies    => _t('Unternehmen',    'Companies');
  String get navMyListings   => _t('Meine Postings', 'My Listings');
  String get navFavorites    => _t('Favoriten',      'Favorites');
  String get navAdmin        => 'Admin';
  String get comingSoonTag   => _t('Bald verfügbar', 'Coming soon');
  String get navPostCapacity => _t('Kapazität posten', 'Post Capacity');
  String get sidebarFeedback => _t('Feedback geben',  'Give feedback');
  String get sidebarInvite   => _t('Firma einladen',  'Invite a company');
  String get sidebarQuote    => _t('"Wo Angebot und Bedarf\nzusammenkommen."', '"Where supply and demand meet."');

  // ── Invite / share dialog ──────────────────────────────────────────────────
  String get inviteTitle       => _t('Ein Unternehmen einladen', 'Invite a company');
  String get inviteSubtitle    => _t('Je mehr Betriebe mitmachen, desto mehr Aufträge und Kapazitäten für alle. Teilen Sie Capacify mit Ihrem Netzwerk.', 'The more companies join, the more jobs and capacity for everyone. Share Capacify with your network.');
  String get inviteMessage     => _t('Ich nutze Capacify — die Live-Kapazitätsbörse für Bauunternehmen in Hamburg. Freie Kapazitäten anbieten oder Partner für Aufträge finden. Kostenlos: https://capacify.de', 'I use Capacify — the live capacity exchange for construction companies in Hamburg. Offer spare capacity or find partners for jobs. Free: https://capacify.de');
  String get inviteCopyLink    => _t('Einladung kopieren', 'Copy invitation');
  String get inviteCopied      => _t('Einladung in die Zwischenablage kopiert', 'Invitation copied to clipboard');
  String get inviteViaEmail    => _t('Per E-Mail einladen', 'Invite via email');
  String get inviteViaWhatsapp => _t('Per WhatsApp einladen', 'Invite via WhatsApp');
  String get inviteEmailSubject => _t('Einladung zu Capacify', 'Invitation to Capacify');

  // ── Poster pull-back: pending requests on own posts ────────────────────────
  String newRequestsBadge(int n) => n == 1
      ? _t('1 neue Anfrage', '1 new request')
      : _t('$n neue Anfragen', '$n new requests');

  // ── Dashboard topbar ─────────────────────────────────────────────────────────
  String get menuProfile      => _t('Profil',       'Profile');
  String get menuCompany      => _t('Unternehmen',  'Company');
  String get menuSettings     => _t('Einstellungen',     'Settings');
  String get menuLogout       => _t('Abmelden',          'Sign out');
  String get topBarTitle      => _t('LIVE KAPAZITÄTSBÖRSE', 'LIVE CAPACITY EXCHANGE');
  String get topBarSubtitle   => '$kServiceRegion · $kServiceRadiusKm km Radius';
  String get accountSettings  => _t('Konto & Einstellungen', 'Account & Settings');
  String get fabPostCapacity  => _t('KAPAZITÄT POSTEN', 'POST CAPACITY');
  String get noCompanyFirst   => _t('Erstellen Sie zuerst ein Unternehmensprofil.', 'Please create a company profile first.');
  String get noCompanyFirst2  => _t('Bitte zuerst Unternehmensprofil erstellen.',   'Please create a company profile first.');

  // ── Stats bar ────────────────────────────────────────────────────────────────
  String get statsAvailable  => _t('Verfügbar', 'Available');
  String get statsNeeded     => _t('Gesucht',   'Needed');
  String totalLabel(int n)   => isEn ? '$n total' : '$n gesamt';

  // ── Feedback dialog ──────────────────────────────────────────────────────────
  String get feedbackTitle    => _t('Feedback & Kontakt',          'Feedback & Contact');
  String get feedbackSubtitle => _t('Direkt an das Capacify-Team', 'Directly to the Capacify team');
  String get feedbackBody     => _t(
    'Haben Sie eine Idee, einen Fehler entdeckt oder möchten Sie uns einfach etwas mitteilen? Wir freuen uns über jede Rückmeldung.',
    'Have an idea, found a bug, or just want to share something? We appreciate every piece of feedback.',
  );
  String get feedbackHint     => _t('Ihre Nachricht an das Capacify-Team...', 'Your message to the Capacify team...');
  String get feedbackSend     => _t('Senden', 'Send');

  // ── Capacities screen ────────────────────────────────────────────────────────
  String get capacitiesTitle    => _t('Kapazitäten', 'Capacities');
  String get capacitiesSubtitle => _t('Freie Kapazitäten anbieten oder suchen', 'Offer or search for free capacities');
  String get capacitiesAddBtn   => _t('Kapazität eintragen', 'Add Capacity');
  String get searchHint         => _t('Suche nach Gewerk, Ort...', 'Search by trade, location...');
  String get tradeAll           => _t('Alle Gewerke', 'All Trades');
  String get typeAll            => _t('Alle',         'All');
  String get typeOffer          => _t('Angebot',      'Offer');
  String get typeNeed           => _t('Gesuch',       'Inquiry');
  String get noCapacitiesFound  => _t('Keine Kapazitäten gefunden', 'No capacities found');
  String get addFirstCapacity   => _t('Tragen Sie Ihre erste Kapazität ein', 'Add your first capacity');
  String get requireCompany     => _t('Bitte zuerst ein Unternehmensprofil erstellen.', 'Please create a company profile first.');

  // ── Report dialog ────────────────────────────────────────────────────────────
  String get reportTooltip  => _t('Beitrag melden', 'Report post');
  String get reportTitle2   => _t('Beitrag melden', 'Report post');
  String get reportSubtitle => _t('Wähle einen Grund aus', 'Select a reason');
  String get reportSubmit   => _t('Melden', 'Report');
  String get reportSuccess  => _t('Beitrag gemeldet. Danke für dein Feedback.', 'Post reported. Thank you for your feedback.');
  String get reportError2   => _t('Fehler beim Melden. Bitte erneut versuchen.', 'Error reporting. Please try again.');

  String get titleAvailableSuffix => _t('verfügbar', 'available');
  String get titleWantedSuffix    => _t('gesucht', 'wanted');

  // Trade/Gewerk display name — the German string is always the canonical
  // stored value; this only translates what's shown to the user.
  String tradeName(String trade) {
    if (!isEn) return trade;
    switch (trade) {
      // Current (consolidated) values
      case 'Rohbau': return 'Shell Construction';
      case 'Trockenbau': return 'Drywall';
      case 'Elektro': return 'Electrical';
      case 'SHK': return 'Plumbing & HVAC';
      case 'Maler': return 'Painter';
      case 'Dach': return 'Roofing';
      case 'Fassade': return 'Facade';
      case 'Gerüstbau': return 'Scaffolding';
      case 'Tiefbau': return 'Civil Engineering';
      case 'Fliesen & Boden': return 'Tiling & Flooring';
      case 'Beton & Stahl': return 'Concrete & Steel';
      case 'Andere': return 'Other';
      // Legacy values — kept so any historical/un-migrated string still
      // translates rather than falling through to the raw German word.
      case 'Generalunternehmer': return 'General Contractor';
      case 'Sanitär & Heizung': return 'Plumbing & Heating';
      case 'Architektur': return 'Architecture';
      case 'Statik': return 'Structural Engineering';
      case 'Stahl': return 'Steel';
      case 'Beton': return 'Concrete';
      case 'HVAC': return 'HVAC';
      case 'Lieferant': return 'Supplier';
      case 'Fliesenleger': return 'Tiler';
      case 'Bodenleger': return 'Flooring';
      default: return trade;
    }
  }

  String reasonLabel(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.wrongInformation:
        return _t('Falsche Informationen', 'Wrong information');
      case ReportReason.fakeCompany:
        return _t('Fake-Unternehmen', 'Fake company');
      case ReportReason.offensiveContent:
        return _t('Anstößiger Inhalt', 'Offensive content');
      case ReportReason.suspiciousBehavior:
        return _t('Verdächtiges Verhalten', 'Suspicious behavior');
    }
  }

  // ── Capacity model labels (status/availability/type/time) ───────────────────
  String get statusActiveBadge      => _t('AKTIV', 'ACTIVE');
  String get statusInProgressBadge  => _t('IN VERHANDLUNG', 'IN NEGOTIATION');
  String get statusAwardedBadge     => _t('VERGEBEN', 'AWARDED');
  String get statusCancelledBadge   => _t('STORNIERT', 'CANCELLED');
  String get availNowBadge          => _t('SOFORT', 'NOW');
  String get availThisWeekBadge     => _t('DIESE WOCHE', 'THIS WEEK');
  String get availNextWeekBadge     => _t('NÄCHSTE WOCHE', 'NEXT WEEK');
  String get availFromPrefix        => _t('AB', 'FROM');
  String get justNowLabel           => _t('gerade eben', 'just now');
  String minutesAgo(int n)          => isEn ? '${n}min ago' : 'vor ${n}min';
  String hoursAgo(int n)            => isEn ? '${n}h ago' : 'vor ${n}h';
  String daysAgoShort(int n)        => isEn ? '${n}d ago' : 'vor ${n}d';
  // Trade-led post titles (lead with the Gewerk, never the poster).
  String postTitleOffer(String trade) => _t('$trade-Kolonne verfügbar', '$trade crew available');
  String postTitleNeed(String trade)  => _t('$trade-Kolonne gesucht', '$trade crew needed');
  // Freshness — honest "updated" copy off updatedAt.
  String get updatedTodayLabel      => _t('Aktualisiert heute', 'Updated today');
  String updatedDaysAgo(int n)      => isEn
      ? 'Updated ${n == 1 ? '1 day' : '$n days'} ago'
      : 'Aktualisiert vor ${n == 1 ? '1 Tag' : '$n Tagen'}';

  // ── Live feed ─────────────────────────────────────────────────────────────────
  String get tabAll              => _t('ALLE', 'ALL');
  String get feedSearchHint      => _t('Gewerk, Ort oder Unternehmen...', 'Trade, location or company...');
  String get sortNearestFirst    => _t('Nächste zuerst', 'Nearest first');
  String get whenLabel           => _t('Wann', 'When');
  String get whenAllTimes        => _t('Alle Zeiten', 'All times');
  String get whenNow             => _t('Sofort verfügbar', 'Available now');
  String get whenThisWeek        => _t('Diese Woche', 'This week');
  String get whenNextWeek        => _t('Nächste Woche', 'Next week');
  String get retryButton         => _t('Erneut versuchen', 'Try again');
  // Crew-size filter (feed facet).
  String get crewLabel           => _t('Teamgröße', 'Crew size');
  String get crewAny             => _t('Beliebige Größe', 'Any size');
  String get crew1plus           => _t('ab 1 Person', '1+ people');
  String get crew3plus           => _t('ab 3 Personen', '3+ people');
  String get crew5plus           => _t('ab 5 Personen', '5+ people');
  String get crew10plus          => _t('ab 10 Personen', '10+ people');
  String get tradeFilterLabel    => _t('Gewerk', 'Trade');
  String get applyFilterButton   => _t('Anwenden', 'Apply');
  String get maxTwoTradesNotice  => _t('Maximal 2 Gewerke auswählen', 'Select up to 2 trades');
  String get selectAtLeastOneTrade => _t('Bitte wählen Sie mindestens ein Gewerk', 'Please select at least one trade');
  String get feedEmptyTitle      => _t('Keine Kapazitäten', 'No capacities');
  String get feedEmptySubtitle   => _t(
    'Passen Sie die Filter an\noder posten Sie eine neue Kapazität.',
    'Adjust the filters\nor post a new capacity.',
  );
  String get loadMoreButton      => _t('Mehr laden', 'Load more');
  // Maps an exception to a friendly, non-leaky message. Raw Firestore/Dart
  // exception text is never shown to the user (unprofessional + minor info
  // leak); common cases (no permission / offline) get a specific message,
  // everything else a generic one.
  String errorWithMessage(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('permission-denied') || s.contains('permission_denied')) {
      return _t('Dazu haben Sie keine Berechtigung.',
          'You don\'t have permission to do that.');
    }
    if (s.contains('unavailable') || s.contains('network') || s.contains('offline')) {
      return _t('Keine Verbindung. Bitte prüfen Sie Ihr Internet und versuchen Sie es erneut.',
          'No connection. Please check your internet and try again.');
    }
    if (s.contains('not-found') || s.contains('not_found')) {
      return _t('Nicht gefunden. Möglicherweise wurde der Eintrag entfernt.',
          'Not found. It may have been removed.');
    }
    return _t('Ein Fehler ist aufgetreten. Bitte erneut versuchen.',
        'Something went wrong. Please try again.');
  }
  String get closeLabel          => _t('Schließen', 'Close');
  String get shareSheetTitle     => _t('Post teilen', 'Share post');
  String get shareFoundOnCapacify => _t(
    'Gefunden auf Capacify – Die Kapazitätsbörse für die Baubranche',
    'Found on Capacify – the capacity marketplace for the construction industry',
  );
  String get shareCopy           => _t('Kopieren', 'Copy');
  String get shareCopiedSnackbar => _t('📋 In Zwischenablage kopiert', '📋 Copied to clipboard');
  String get noContactDataSnackbar => _t(
    'Keine Kontaktdaten für diese Kapazität hinterlegt',
    'No contact details available for this capacity',
  );
  String interestEmailSubject(String title) => _t('Interesse: $title', 'Interest: $title');
  String interestEmailBody(String title) => _t(
    'Guten Tag,\n\nIch habe Ihr Posting "$title" auf Capacify gesehen und bin daran interessiert.\n\nIch würde mich gerne mit Ihnen in Verbindung setzen.\n\nMit freundlichen Grüßen',
    'Hello,\n\nI saw your posting "$title" on Capacify and I am interested.\n\nI would like to get in touch with you.\n\nBest regards',
  );
  String get mailAppError    => _t('E-Mail-Programm konnte nicht geöffnet werden', 'Could not open email app');
  String get newBadge        => _t('NEU', 'NEW');
  String get seenLabel       => _t('gesehen', 'seen');
  String get expressInterest => _t('Interesse bekunden', 'Express interest');
  String get removeFavoriteTooltip => _t('Aus Favoriten entfernen', 'Remove from favorites');
  String get addFavoriteTooltip    => _t('Zu Favoriten hinzufügen', 'Add to favorites');
  String get shareTooltip    => _t('Teilen', 'Share');
  String get detailsTooltip  => _t('Details', 'Details');

  // ── My postings (Meine Postings) ─────────────────────────────────────────────
  String get myPostingsTitle    => _t('Meine Postings', 'My Listings');
  String get statusActiveTitle      => _t('Aktiv', 'Active');
  String get negotiationShortLabel  => _t('Verhandlung', 'Negotiation');
  String get negotiationLabel       => _t('In Verhandlung', 'In negotiation');
  String get statusAwardedTitle     => _t('Vergeben', 'Awarded');
  String get statusCancelledTitle   => _t('Storniert', 'Cancelled');
  String get newPostingButton       => _t('Neu', 'New');
  String noPostingsUnderFilter(String f) => _t('Keine Postings unter "$f"', 'No postings under "$f"');
  String get confirmAwardTitle       => _t('Auftrag vergeben?', 'Award job?');
  String get confirmNegotiationTitle => _t('In Verhandlung setzen?', 'Set to negotiation?');
  String get confirmCancelTitle      => _t('Posting stornieren?', 'Cancel posting?');
  String get confirmStatusChangeTitle=> _t('Status ändern?', 'Change status?');
  String confirmAwardBody(String title) => _t(
    '"$title" wird als vergeben markiert und aus dem Live-Feed entfernt. Die Daten bleiben erhalten.',
    '"$title" will be marked as awarded and removed from the live feed. The data will be kept.',
  );
  String confirmNegotiationBody(String title) => _t(
    '"$title" wird als "In Verhandlung" markiert und bleibt im Feed sichtbar.',
    '"$title" will be marked as "In negotiation" and remains visible in the feed.',
  );
  String confirmCancelBody(String title) => _t(
    '"$title" wird storniert und aus dem Feed entfernt. Die Daten bleiben erhalten.',
    '"$title" will be cancelled and removed from the feed. The data will be kept.',
  );
  String get cancelActionLabel   => _t('Stornieren', 'Cancel');
  String get confirmGenericLabel => _t('Bestätigen', 'Confirm');
  String get statusUpdatedPrefix => _t('Status aktualisiert:', 'Status updated:');
  String interestedCount(int n)  => _t('$n Interessenten', '$n interested');
  String get awardJobAction      => _t('Auftrag vergeben', 'Award job');

  // ── Capacity detail screen ───────────────────────────────────────────────────
  String get noPhoneSnackbar  => _t('Keine Telefonnummer hinterlegt', 'No phone number available');
  String get callFailedSnackbar => _t('Anruf konnte nicht gestartet werden', 'Could not start the call');
  String get noEmailSnackbar  => _t('Keine E-Mail hinterlegt', 'No email available');
  String copiedSuffix(String label) => _t('$label kopiert', '$label copied');
  String get confirmBackToActiveTitle => _t('Zurück auf Aktiv setzen?', 'Set back to active?');
  String confirmBackToActiveBody(String title) => _t(
    '"$title" wird wieder als aktiv markiert und ist normal im Feed sichtbar.',
    '"$title" will be marked active again and is normally visible in the feed.',
  );
  String confirmCloseBody(String title) => _t(
    '"$title" wird als abgeschlossen markiert und aus dem Live-Feed entfernt. Die Daten bleiben gespeichert.',
    '"$title" will be marked as completed and removed from the live feed. The data will be kept.',
  );
  String get confirmAwardCheckLabel => _t('Vergeben ✓', 'Awarded ✓');
  String get negotiationStaysVisibleBody => _t(
    'Dieser Post bleibt im Feed sichtbar, wird aber als "In Verhandlung" markiert.',
    'This post remains visible in the feed, but will be marked as "In negotiation".',
  );
  String get statusNegotiationSnackbar => _t('Status: In Verhandlung', 'Status: In negotiation');
  String get statusActiveSnackbar      => _t('Status: Aktiv', 'Status: Active');
  String get postingCancelledSnackbar  => _t('Posting storniert', 'Posting cancelled');
  String get locationLabel        => _t('Ort', 'Location');
  String get availabilityLabelText => _t('Verfügbarkeit', 'Availability');
  String get completedLabel       => _t('Abgeschlossen', 'Completed');
  String get descriptionLabel     => _t('Beschreibung', 'Description');
  String viewsCount(int n)        => _t('$n Aufrufe', '$n views');
  String favoritesCount(int n)    => _t('$n Favoriten', '$n favorites');
  String get contactLabel         => _t('Kontakt', 'Contact');
  String get noContactInfoText    => _t('Keine Kontaktdaten hinterlegt', 'No contact details available');
  String get jobAwardedArchivedNotice => _t(
    'Dieser Auftrag wurde vergeben. Die Daten sind archiviert.',
    'This job has been awarded. The data is archived.',
  );
  String dealNumberLabel(int n) => _t('Deal-Nr. $n', 'Deal #$n');
  String get postingCancelledNotice => _t('Dieses Posting wurde storniert.', 'This posting has been cancelled.');
  String postedAt(String time)    => _t('Gepostet $time', 'Posted $time');
  String get setNegotiationButton => _t('In Verhandlung setzen', 'Set to negotiation');
  String get setActiveButton      => _t('Zurück auf Aktiv setzen', 'Set back to active');
  String get awardJobButtonCaps   => _t('AUFTRAG VERGEBEN', 'AWARD JOB');
  String get cancelPostingButton  => _t('Posting stornieren', 'Cancel posting');
  String get callButton           => _t('Anrufen', 'Call');
  String get priceProposalTip     => _t('Tipp: Schlagen Sie direkt einen Preis vor, um das Gespräch produktiver zu machen.', 'Tip: Suggest a price upfront to make the conversation more productive.');
  String get contactGateMessage   => _t('Vervollständigen Sie Ihr Unternehmensprofil, um Unternehmen kontaktieren zu können.', 'Complete your company profile to be able to contact companies.');
  String get contactGateButton    => _t('Profil vervollständigen', 'Complete profile');
  String copyTooltip(String label) => _t('$label kopieren', 'Copy $label');

  // ── Company profile (Unternehmensprofil) ─────────────────────────────────────
  String get profileSavedSuccess => _t('Profil erfolgreich gespeichert.', 'Profile saved successfully.');
  String get saveErrorRetry      => _t('Fehler beim Speichern. Bitte erneut versuchen.', 'Error saving. Please try again.');
  String get companyProfileTitle    => _t('Unternehmensprofil', 'Company Profile');
  String get companyProfileSubtitle => _t('Präsentieren Sie Ihr Unternehmen auf Capacify', 'Present your company on Capacify');
  String get logoUploadHint => _t('Tippen, um ein Logo hochzuladen', 'Tap to upload a logo');
  String get contactPersonLabel => _t('Ansprechpartner', 'Contact');
  String get logoChangeHint => _t('Tippen, um das Logo zu ändern', 'Tap to change the logo');
  String get logoChange => _t('Logo ändern', 'Change logo');
  String get logoRemove => _t('Logo entfernen', 'Remove logo');
  String get logoRemoved => _t('Logo entfernt', 'Logo removed');
  String get basicInfoSection     => _t('Grundinformationen', 'Basic Information');
  String get tradeBranchLabel     => _t('Gewerk / Branche *', 'Trade / Industry *');
  String get descriptionRequiredLabel => _t('Beschreibung *', 'Description *');
  String get describeCompanyHint  => _t('Beschreiben Sie Ihr Unternehmen...', 'Describe your company...');
  String get certificationsLabel  => _t('Qualifikationen & Mitgliedschaften', 'Qualifications & memberships');
  String get certificationsHint   => _t('z. B. Meisterbetrieb, Innung SHK Hamburg, Betriebshaftpflicht', 'e.g. master craftsman, guild membership, liability insurance');
  String get certificationsTitle  => _t('Qualifikationen & Mitgliedschaften', 'Qualifications & memberships');
  String get contactInfoSection   => _t('Kontaktinformationen', 'Contact Information');
  String get websiteHint          => _t('https://www.ihre-firma.de', 'https://www.your-company.com');
  String get locationSection      => _t('Standort', 'Location');
  String profileCompletePercent(int percent) => _t('Profil zu $percent% vervollständigt', 'Profile $percent% complete');
  String get incompleteProfileBannerTitle => _t('Vervollständigen Sie Ihr Unternehmensprofil', 'Complete your company profile');
  String incompleteProfileBannerSubtitle(int percent) => _t('Nur zu $percent% ausgefüllt — andere sehen mehr, wenn Ihr Profil vollständig ist.', 'Only $percent% filled in — others will see more once your profile is complete.');
  String get completeProfileButton => _t('Jetzt vervollständigen', 'Complete now');
  // Getting-started activation card (new-user first-run path).
  String get gettingStartedTitle    => _t('Erste Schritte', 'Get started');
  String get gettingStartedSubtitle => _t('In 3 Schritten sichtbar für Hamburgs Baufirmen — und startklar für Kooperationen.', 'Three steps to being visible to Hamburg\'s construction firms — and ready to collaborate.');
  String get gsStepProfile          => _t('Unternehmensprofil vervollständigen', 'Complete your company profile');
  String get gsStepPost             => _t('Erste Kapazität posten', 'Post your first capacity');
  String get gsStepAlerts           => _t('E-Mail-Benachrichtigungen einschalten', 'Turn on email alerts');
  String get addressLabel         => _t('Adresse', 'Address');
  String get addressHint          => _t('Musterstraße 1', '123 Main Street');
  String get postalCodeLabel      => _t('PLZ', 'Postal code');
  String get companyDetailsSection => _t('Unternehmensdetails', 'Company Details');
  String get employeeCountLabel   => _t('Mitarbeiteranzahl', 'Number of Employees');
  String employeesSuffix(String e) => _t('$e Mitarbeiter', '$e employees');
  String get servicesLabel        => _t('Leistungen', 'Services');
  String get saveProfileButton    => _t('Profil speichern', 'Save Profile');

  // ── Company directory (Unternehmen) ──────────────────────────────────────────
  String companiesCountBadge(int n) => _t('$n Unternehmen', '$n Companies');
  String get directorySubtitle    => _t('Entdecken Sie Partnerunternehmen in Ihrer Region.', 'Discover partner companies in your region.');
  String get directorySearchHint  => _t('Name, Stadt oder Gewerk...', 'Name, city or trade...');
  String get onlyVerifiedFilter   => _t('Nur Verifiziert', 'Verified only');
  String get noCompaniesFound     => _t('Keine Unternehmen gefunden', 'No companies found');
  String get adjustFiltersText    => _t('Passen Sie die Filter an.', 'Adjust the filters.');
  String get verificationPendingBadge => _t('PRÜFUNG LÄUFT', 'PENDING REVIEW');
  String get registeredBadge      => _t('REGISTRIERT', 'REGISTERED');

  // ── My profile (Mein Profil) ─────────────────────────────────────────────────
  String get passwordChangedSuccess => _t('Passwort wurde erfolgreich geändert', 'Password changed successfully');
  String get profileFallback      => _t('Profil', 'Profile');
  String memberSince(int year)    => _t('Mitglied seit $year', 'Member since $year');
  String get personalInfoSection  => _t('Persönliche Informationen', 'Personal Information');
  String get firstNameLabelPlain  => _t('Vorname', 'First name');
  String get lastNameLabelPlain   => _t('Nachname', 'Last name');
  String get jobTitleLabel        => _t('Beruf/Position', 'Job title/Position');
  String get jobTitleHint         => _t('z.B. Projektleiter', 'e.g. Project manager');
  String get saveButtonGeneric    => _t('Speichern', 'Save');
  String get accountSection       => _t('Konto', 'Account');
  String get emailAddressLabel    => _t('E-Mail-Adresse', 'Email address');
  String get changeButton         => _t('Ändern', 'Change');

  // ── Favorites (Favoriten) ────────────────────────────────────────────────────
  String get noFavoritesYet      => _t('Noch keine Favoriten', 'No favorites yet');
  String get tapHeartToSaveHint  => _t('Tippen Sie auf ❤ in einem Post\num ihn zu speichern.', 'Tap ❤ on a post\nto save it.');

  // ── Create capacity ───────────────────────────────────────────────────────────
  String get fillTradeLocationDescription => _t('Bitte Gewerk, Standort und Beschreibung ausfüllen', 'Please fill in trade, location and description');
  String get capacityNowLive      => _t('🟢 Kapazität ist jetzt LIVE!', '🟢 Capacity is now LIVE!');
  String get thirtySecondsToLive  => _t('30 Sekunden bis Sie LIVE sind', "30 seconds until you're LIVE");
  String get section1Type         => _t('1. Art der Kapazität', '1. Type of capacity');
  String get weAreAvailable       => _t('Wir sind verfügbar', 'We are available');
  String get weAreSearching       => _t('Wir suchen Kapazität', 'We are looking for capacity');
  // Visibility mode — chosen once per post, immutable afterward (see
  // CapacityModel.visibilityMode). Placed right after Type since it's as
  // fundamental a choice as offer/need.
  String get section2Visibility   => _t('2. Sichtbarkeit', '2. Visibility');
  String get visibilityVisibleLabel => _t('Sichtbar', 'Visible');
  String get visibilityVisibleSubtitle => _t(
      'Firmenname, Logo und Verifizierung werden angezeigt. Kontakt bleibt bis zur ersten Nachricht geschützt.',
      'Your name, logo and verification are shown. Contact details stay protected until the first message.');
  String get visibilityDiscreetLabel => _t('Diskret', 'Discreet');
  String get visibilityDiscreetSubtitle => _t(
      'Firmenname sichtbar, aber zurückhaltender dargestellt — ein ruhigerer Auftritt.',
      'Your name is shown, but framed more discreetly — a quieter presence.');
  String get visibilityAnonymousLabel => _t('Anonym', 'Anonymous');
  String get visibilityAnonymousSubtitle => _t(
      'Ihre Identität bleibt verborgen, bis Sie eine Anfrage annehmen — ideal, wenn Mitbewerber Ihre freie Kapazität nicht sehen sollen.',
      "Your identity stays hidden until you accept a request — best if you don't want competitors to see your free capacity.");
  String get section3Trade        => _t('3. Gewerk auswählen', '3. Select trade');
  String get section4When         => _t('4. Wann verfügbar?', '4. When available?');
  String get availNowAllCaps      => _t('SOFORT VERFÜGBAR', 'AVAILABLE NOW');
  String get availableFromTodaySubtitle => _t('Ab heute einsetzbar', 'Can start today');
  String get within7DaysSubtitle  => _t('Innerhalb der nächsten 7 Tage', 'Within the next 7 days');
  String get in7to14DaysSubtitle  => _t('In 7-14 Tagen verfügbar', 'Available in 7-14 days');
  String get chooseDateLabel      => _t('Zeitraum wählen', 'Choose date range');
  String get chooseDateFromCalendar => _t('Zeitraum aus Kalender wählen', 'Choose date range from calendar');
  String get startDateChip       => _t('Start', 'Start');
  String get endDateChip         => _t('Ende', 'End');
  String get section5LocationHamburg => _t('5. Standort in Hamburg', '5. Location in Hamburg');
  String get section6WorkerCount  => _t('6. Teamgröße', '6. Team size');
  String get section7Description  => _t('7. Beschreibung (optional)', '7. Description (optional)');
  String get descriptionExampleHint => _t(
    'z.B. "5 Trockenbauer ab Montag, alle Werkzeuge dabei, Führerschein vorhanden..."',
    'e.g. "5 drywall workers from Monday, all tools included, driver\'s license available..."',
  );
  String get section8AdditionalDetails => _t('8. Zusätzliche Angaben (optional)', '8. Additional details (optional)');
  String get skillDetailsLabel => _t('Qualifikationen / Ausrüstung', 'Qualifications / equipment');
  String get skillDetailsHint => _t(
    'z.B. "Hubarbeitsbühne-Schein, Führerschein Kl. B"',
    'e.g. "Aerial platform license, Class B driver\'s license"',
  );
  String get dayRateBandLabel => _t('Tagessatz (optional)', 'Day rate (optional)');
  // Short form (no "(optional)") for read-only display — e.g. prefixed onto
  // the band value in the trust block, where a bare "800€+" gave no
  // indication of what the number even was (day rate, total budget, hourly?).
  String get dayRateBandTrustLabel => _t('Tagessatz', 'Day rate');
  String get dayRateBandUndisclosed => _t('Nicht angeben', 'Prefer not to say');
  String dayRateBandName(String band) {
    switch (band) {
      case 'unter_300': return _t('unter 300€', 'under €300');
      case '300_500': return _t('300–500€', '€300–500');
      case '500_800': return _t('500–800€', '€500–800');
      case 'ueber_800': return _t('800€+', '€800+');
      default: return dayRateBandUndisclosed;
    }
  }
  String get previewLabel         => _t('Vorschau', 'Preview');
  String get postNowButton        => _t('Jetzt posten', 'Post now');

  // ── Edit capacity ─────────────────────────────────────────────────────────────
  String get capacityUpdatedSuccess => _t('Kapazität aktualisiert.', 'Capacity updated.');
  String get saveErrorGeneric     => _t('Fehler beim Speichern.', 'Error saving.');
  String get editCapacityTitle    => _t('Kapazität bearbeiten', 'Edit Capacity');
  String get endedBadge           => _t('BEENDET', 'ENDED');
  String get titleRequiredLabel   => _t('Titel *', 'Title *');
  String get locationRequiredLabel => _t('Ort *', 'Location *');
  String get countRequiredLabel   => _t('Teamgröße *', 'Team size *');
  String get fromDateLabel        => _t('Von *', 'From *');
  String get toDateLabel          => _t('Bis *', 'To *');
  String get statusFieldLabel     => 'Status';
  String get activeStatusButton   => _t('Aktiv', 'Active');
  String get endedStatusButton    => _t('Beendet', 'Ended');

  // ── Company detail (public view) ─────────────────────────────────────────────
  String get noLocationText       => _t('Kein Standort', 'No location');
  String get aboutCompanySection  => _t('Über das Unternehmen', 'About the company');

  // ── Ratings ───────────────────────────────────────────────────────────────────
  String get rateCompanyButton    => _t('Bewerten', 'Rate');
  String get editRatingButton     => _t('Bewertung bearbeiten', 'Edit rating');
  String get rateNeedsCollaborationTooltip => _t(
      'Bewertungen sind erst nach einer angenommenen Kontaktanfrage möglich.',
      'Rating is only available after an accepted contact request.');
  String rateCompanyDialogTitle(String companyName) => _t('$companyName bewerten', 'Rate $companyName');
  String get yourRatingLabel      => _t('Ihre Bewertung', 'Your rating');
  String get commentOptionalLabel => _t('Kommentar (optional)', 'Comment (optional)');
  String get commentOptionalHint  => _t('Wie war die Zusammenarbeit?', 'How was working with them?');
  String get submitRatingButton   => _t('Bewertung abschicken', 'Submit rating');
  String get ratingSubmittedSuccess => _t('Bewertung gespeichert', 'Rating saved');
  String get deleteRatingButton   => _t('Bewertung löschen', 'Delete rating');
  String get deleteRatingConfirmTitle => _t('Bewertung löschen?', 'Delete rating?');
  String get deleteRatingConfirmBody => _t('Diese Bewertung wird endgültig entfernt und kann nicht wiederhergestellt werden.', 'This rating will be permanently removed and cannot be restored.');
  // Only offered once the underlying post is closed/cancelled (see
  // ChatScreen) — deleteChat (Cloud Function) enforces this server-side too.
  String get deleteChatAction => _t('Chat löschen', 'Delete chat');
  String get deleteChatConfirmTitle => _t('Chat löschen?', 'Delete chat?');
  String get deleteChatConfirmBody => _t(
      'Dieser Chat wird endgültig entfernt und kann nicht wiederhergestellt werden.',
      'This chat will be permanently removed and cannot be restored.');
  String get ratingDeletedSnackbar => _t('Bewertung gelöscht', 'Rating deleted');
  String get selectRatingValidation => _t('Bitte wählen Sie eine Bewertung', 'Please select a rating');
  String get reviewsSectionTitle  => _t('Bewertungen', 'Reviews');
  String get noReviewsYetText     => _t('Noch keine Bewertungen', 'No reviews yet');
  String get yourRatingSectionTitle => _t('Ihre Bewertung', 'Your rating');
  String get noRatingYetOwnText   => _t('Sie haben noch keine Bewertungen erhalten.', 'You haven\'t received any ratings yet.');

  // ── Company analytics ────────────────────────────────────────────────────────
  String get companyAnalyticsTitle => _t('Unternehmensanalytics', 'Company Analytics');
  String get keyMetricsTitle      => _t('Kennzahlen', 'Key Metrics');
  String get profileViewsLabel    => _t('Profilaufrufe', 'Profile views');
  String plusThisWeek(int n)      => _t('+$n diese Woche', '+$n this week');
  String get interestedPartiesLabel => _t('Interessenten', 'Interested parties');
  String get activeCapacitiesLabel => _t('Aktive Kapazitäten', 'Active capacities');
  String get allActiveText        => _t('Alle aktiv', 'All active');
  String get recentActivityTitle  => _t('Letzte Aktivität', 'Recent Activity');
  String get profileUpdatedText   => _t('Profil aktualisiert', 'Profile updated');
  String daysAgoFull(int n)       => _t('Vor $n Tagen', '$n days ago');
  String get newRequestReceivedText => _t('Neue Anfrage erhalten', 'New request received');
  String get capacityCreatedText  => _t('Kapazität erstellt', 'Capacity created');
  String get oneWeekAgoText       => _t('Vor 1 Woche', '1 week ago');
  String get ratingTrustTitle     => _t('Bewertung & Vertrauen', 'Rating & Trust');
  String get ratingLabel          => _t('Bewertung', 'Rating');
  String ratingsCount(int n)      => _t('($n Bewertungen)', '($n ratings)');
  String trustScoreText(int score) => _t('Vertrauensscore: $score/100', 'Trust score: $score/100');
  String get verifiedTitleCase    => _t('Verifiziert', 'Verified');

  // ── About screen ──────────────────────────────────────────────────────────────
  String get aboutParagraph1 => _t(
    'Capacify wurde geschaffen, um ein einfaches Problem zu lösen: Bauunternehmen benötigen oft zusätzliche Kapazitäten, während andere qualifizierte Teams verfügbar haben — doch sie finden sich selten rechtzeitig.',
    'Capacify was created to solve a simple problem: construction companies often need additional capacity, while others have skilled teams available — yet they rarely find each other in time.',
  );
  String get aboutParagraph2 => _t(
    'Unsere Mission ist es, Kapazitäten sichtbar zu machen, Leerlaufzeiten zu reduzieren und Unternehmen durch ein vertrauenswürdiges Echtzeit-Netzwerk schneller miteinander zu verbinden.',
    'Our mission is to make capacity visible, reduce downtime, and help companies connect faster through a trusted, real-time network.',
  );
  String get aboutNoTenders => _t(
    'Keine langwierigen Ausschreibungen. Keine endlosen Telefonate.',
    'No lengthy tenders. No endless phone calls.',
  );
  String get aboutRightCapacity => _t(
    'Einfach die richtige Kapazität zur richtigen Zeit.',
    'Just the right capacity at the right time.',
  );

  // ── Settings screen ───────────────────────────────────────────────────────────
  String get settingsTitle        => _t('Einstellungen', 'Settings');
  String get notificationsSection => _t('BENACHRICHTIGUNGEN', 'NOTIFICATIONS');
  String get emailNotificationsTitle => _t('E-Mail Benachrichtigungen', 'Email notifications');
  String get emailNotificationsSubtitle => _t('Bei neuen Anfragen zu Ihren Anzeigen', 'When you receive a new request on your posts');
  String get newCapacitiesTitle   => _t('Neue passende Kapazitäten', 'New matching capacities');
  String get newPostingsSubtitle  => _t('E-Mail bei neuen Treffern in Ihrem Gewerk + Wochenüberblick', 'Email on new matches in your trade + weekly overview');
  String get messagesTitle        => _t('Nachrichten', 'Messages');
  String get newMessagesSubtitle  => _t('Benachrichtigung bei neuen Nachrichten', 'Notification for new messages');
  String get legalSection         => _t('RECHTLICHES', 'LEGAL');
  String get agbFullName          => _t('Allgemeine Geschäftsbedingungen', 'Terms and Conditions');
  String get gdprSubtitle         => _t('DSGVO Datenschutz', 'GDPR Privacy');
  String get tmgSubtitle          => _t('Angaben gemäß §5 TMG', 'Disclosure per §5 TMG');
  String get aboutCapacifySection => _t('ÜBER CAPACIFY', 'ABOUT CAPACIFY');
  String get liveCapacityExchangeTagline => _t('Live Kapazitätsbörse', 'Live Capacity Exchange');
  String get developerSection     => _t('ENTWICKLER', 'DEVELOPER');
  String get accountSectionCaps   => _t('KONTO', 'ACCOUNT');
  String get changePasswordTitle  => _t('Passwort ändern', 'Change password');
  String get setNewPasswordSubtitle => _t('Neues Passwort festlegen', 'Set new password');
  String get referralsTitle => _t('Empfehlungen', 'Referrals');
  String referralsCountSubtitle(int n) => n == 1
      ? _t('1 Unternehmen über Ihren Link beigetreten', '1 company joined via your link')
      : _t('$n Unternehmen über Ihren Link beigetreten', '$n companies joined via your link');
  String get referralsNoneYetSubtitle => _t('Firma einladen — Ihr persönlicher Link', 'Invite a company — your personal link');
  String get signOutSubtitle      => _t('Vom Konto abmelden', 'Sign out of account');
  String get currentPasswordLabel => _t('Aktuelles Passwort', 'Current password');
  String get newPasswordLabel     => _t('Neues Passwort', 'New password');
  String get min6CharsError       => _t('Mindestens 6 Zeichen', 'At least 6 characters');
  String get confirmNewPasswordLabel => _t('Neues Passwort bestätigen', 'Confirm new password');
  String get passwordsDontMatchError => _t('Passwörter stimmen nicht überein', 'Passwords do not match');
  String get demoDataSeededSuccess => _t('20 Beispiel-Postings + 6 Unternehmen eingespielt', '20 sample postings + 6 companies seeded');
  String get clearDemoDataTitle   => _t('Demo-Daten löschen?', 'Clear demo data?');
  String get clearDemoDataBody    => _t(
    'Alle 6 Beispiel-Unternehmen und 20 Beispiel-Postings werden aus Firestore gelöscht.',
    'All 6 sample companies and 20 sample postings will be deleted from Firestore.',
  );
  String get deleteButton         => _t('Löschen', 'Delete');
  String get demoDataClearedSuccess => _t('Demo-Daten wurden gelöscht', 'Demo data has been cleared');
  String get sampleDataTitle      => _t('Beispiel-Daten', 'Sample Data');
  String get sampleDataSubtitle   => _t('6 Unternehmen + 20 Postings als Beispiel', '6 companies + 20 postings as sample');
  String get seedSampleDataButton => _t('Beispiel-Daten einspielen', 'Seed sample data');
  String get clearSampleDataButton => _t('Beispiel-Daten löschen', 'Clear sample data');
  String get seedDemoRatingsButton => _t('Bewertungen hinzufügen', 'Add ratings');
  String get demoRatingsSeededSuccess => _t('Bewertungen für Demo-Unternehmen hinzugefügt', 'Ratings added for demo companies');

  // ── Admin panel ───────────────────────────────────────────────────────────────
  String get adminPanelTitle      => 'Admin Panel';
  String get adminBadge           => 'ADMIN';
  String get overviewTab          => _t('DASHBOARD', 'DASHBOARD');
  String get verificationTab      => _t('VERIFIZIERUNG', 'VERIFICATION');
  String get companiesTabCaps     => _t('UNTERNEHMEN', 'COMPANIES');
  String get platformOverviewSection => _t('PLATTFORM-ÜBERSICHT', 'PLATFORM OVERVIEW');
  String get pendingLabel         => _t('Ausstehend', 'Pending');
  String get activePostsLabel     => _t('Aktive Posts', 'Active posts');
  String get platformHealthSection => _t('PLATTFORM-GESUNDHEIT', 'PLATFORM HEALTH');
  String get verificationRateLabel => _t('Verifizierungsrate', 'Verification rate');
  String get pendingReviewsLabel  => _t('Ausstehende Prüfungen', 'Pending reviews');
  String get noneLabel            => _t('Keine', 'None');
  String waitingCount(int n)      => _t('$n warten', '$n waiting');

  // ── Admin Dashboard (operational control center) ───────────────────────────
  String get kpiRegistered        => _t('Registrierte Unternehmen', 'Registered companies');
  String get kpiVerified          => _t('Verifizierte Unternehmen', 'Verified companies');
  String get kpiActive30          => _t('Aktiv (30 Tage)', 'Active (30 days)');
  String get kpiActiveListings    => _t('Aktive Anzeigen', 'Active listings');
  String get kpiNewRegs30         => _t('Neue Registrierungen (30T)', 'New registrations (30d)');
  String get kpiNewListings30     => _t('Neue Anzeigen (30T)', 'New listings (30d)');

  String get dashGrowthSection    => _t('WACHSTUM', 'GROWTH');
  String get growthRegs7          => _t('Registrierungen (7 Tage)', 'Registrations (7 days)');
  String get growthRegs30         => _t('Registrierungen (30 Tage)', 'Registrations (30 days)');
  String get growthListings7      => _t('Anzeigen (7 Tage)', 'Listings (7 days)');
  String get growthListings30     => _t('Anzeigen (30 Tage)', 'Listings (30 days)');
  String get growthAvgPerCompany  => _t('Ø Anzeigen pro Unternehmen', 'Avg listings per company');
  String get growthMin1           => _t('Unternehmen mit ≥ 1 Anzeige', 'Companies with ≥ 1 listing');
  String get growthMin2           => _t('Unternehmen mit ≥ 2 Anzeigen', 'Companies with ≥ 2 listings');

  String get healthCompaniesNoListing => _t('Unternehmen ohne Anzeige', 'Companies without a listing');
  String get healthInactive30     => _t('Inaktiv seit 30+ Tagen', 'Inactive 30+ days');
  String get healthInactive60     => _t('Inaktiv seit 60+ Tagen', 'Inactive 60+ days');
  String get healthOpenVerifications => _t('Offene Prüfungen', 'Open verifications');
  String get healthOpenModerations => _t('Offene Moderationen', 'Open moderations');

  String get dashGewerkeSection   => _t('GEWERKE-PERFORMANCE', 'TRADE PERFORMANCE');
  String gewerkeStat(int listings, int companies) =>
      _t('$listings Anzeigen · $companies Firmen', '$listings listings · $companies firms');

  String get dashOnboardingSection => _t('ONBOARDING-FUNNEL', 'ONBOARDING FUNNEL');
  String get funnelRegistered     => _t('Registriert', 'Registered');
  String get funnelProfileComplete => _t('Profil vollständig', 'Profile complete');
  String get funnelFirstListing   => _t('Erste Anzeige', 'First listing');
  String get funnelSecondListing  => _t('Zweite Anzeige', 'Second listing');
  String get funnelActive30       => _t('Aktiv (30 Tage)', 'Active (30 days)');

  String get dashLiquiditySection => _t('MARKTPLATZ-LIQUIDITÄT', 'MARKETPLACE LIQUIDITY');
  String get liqOffers            => _t('Verfügbare Kapazitäten', 'Available capacity');
  String get liqNeeds             => _t('Gesuche', 'Requests');
  String get liqAvgPerDay         => _t('Ø Anzeigen pro Tag', 'Avg listings per day');
  String get liqAvgDuration       => _t('Ø Anzeigenlaufzeit', 'Avg listing age');
  String daysShort(int n)         => _t('$n Tage', '$n days');

  String get dashInsightsSection  => _t('KI-ERKENNTNISSE', 'AI INSIGHTS');
  String insightTopTrade(String trade, int pct) =>
      _t('$trade erzeugt $pct% aller Anzeigen.', '$trade generates $pct% of all listings.');
  String insightNoListing(int n) => _t(
      '$n Unternehmen haben sich registriert, aber noch keine Anzeige erstellt.',
      '$n companies registered but have not posted a listing yet.');
  String insightTopCity(String city) =>
      _t('$city ist aktuell die aktivste Region.', '$city is currently the most active region.');
  String insightVerification(int pct) =>
      _t('$pct% der Unternehmen sind verifiziert.', '$pct% of companies are verified.');
  String insightGrowth(int n) =>
      _t('$n neue Registrierungen in den letzten 30 Tagen.', '$n new registrations in the last 30 days.');
  String insightInactive(int n) => _t(
      '$n Unternehmen sind seit über 30 Tagen inaktiv — Reaktivierung lohnt sich.',
      '$n companies have been inactive for 30+ days — worth reactivating.');
  String get insightNeedMore      => _t('Noch zu wenig Aktivität für belastbare Erkenntnisse.', 'Not enough activity yet for meaningful insights.');

  String get dashConversionSection => _t('CONVERSION', 'CONVERSION');
  String get convVisitors         => _t('Website-Besucher', 'Website visitors');
  String get convVisitorsHint     => _t('in Google Analytics', 'in Google Analytics');
  String get convFirstListing     => _t('Mit 1. Anzeige', 'With 1st listing');
  String get convSecondListing    => _t('Mit 2. Anzeige', 'With 2nd listing');

  String get dashActionSection    => _t('AKTIONSCENTER', 'ACTION CENTER');
  String get actionNeverPosted    => _t('Registriert, aber ohne Anzeige', 'Registered but never posted');
  String get actionPostedInactive => _t('1 Anzeige, dann 30+ Tage inaktiv', '1 listing, then inactive 30+ days');
  String get actionIncompleteProfile => _t('Unvollständiges Profil', 'Incomplete profile');
  String get actionContact        => _t('Kontaktieren', 'Contact');
  String get actionCheckProfile   => _t('Profil prüfen', 'Check profile');
  String actionMore(int n)        => _t('+ $n weitere', '+ $n more');
  String get actionAllClear       => _t('Keine offenen Aktionen — alles im grünen Bereich.', 'No open actions — all clear.');
  String get setupAdminAccessSection => _t('ADMIN-ZUGANG EINRICHTEN', 'SET UP ADMIN ACCESS');
  String get addNewAdminLabel     => _t('Neuen Admin hinzufügen:', 'Add new admin:');
  String get addAdminInstructions => _t(
    '1. Firebase Console → Firestore\n'
    '2. Kollektion "users" öffnen\n'
    '3. Dokument des Nutzers auswählen\n'
    '4. Feld hinzufügen: isAdmin (boolean) = true',
    '1. Firebase Console → Firestore\n'
    '2. Open the "users" collection\n'
    '3. Select the user\'s document\n'
    '4. Add field: isAdmin (boolean) = true',
  );
  String get noPendingRequestsTitle => _t('Keine ausstehenden Anfragen', 'No pending requests');
  String get allCompaniesReviewedText => _t('Alle Unternehmen sind geprüft.', 'All companies have been reviewed.');
  String get confirmVerificationTitle => _t('Verifizierung bestätigen?', 'Confirm verification?');
  String get rejectVerificationTitle => _t('Verifizierung ablehnen?', 'Reject verification?');
  String verificationApprovedBody(String name) => _t(
    '"$name" erhält das VERIFIZIERT-Badge. Ihre aktiven Posts werden ebenfalls aktualisiert.',
    '"$name" will receive the VERIFIED badge. Their active posts will also be updated.',
  );
  String verificationRejectedBody(String name) => _t(
    '"$name" wird abgelehnt. Das Unternehmen kann später erneut einen Antrag stellen.',
    '"$name" will be rejected. The company can reapply later.',
  );
  String get verifyCheckLabel     => _t('Verifizieren ✓', 'Verify ✓');
  String get rejectLabel          => _t('Ablehnen', 'Reject');
  String companyVerifiedSnackbar(String name) => _t('$name verifiziert ✓', '$name verified ✓');
  String companyRejectedSnackbar(String name) => _t('$name abgelehnt', '$name rejected');
  String sinceDateLabel(String date) => _t('Seit $date', 'Since $date');
  String get verifyButtonCaps     => _t('VERIFIZIEREN', 'VERIFY');
  String get rejectButtonCaps     => _t('ABLEHNEN', 'REJECT');

  // ── Admin panel — ratings moderation ───────────────────────────────────────────
  String get ratingsTab            => _t('BEWERTUNGEN', 'RATINGS');
  String get noPendingRatingsTitle => _t('Keine ausstehenden Bewertungen', 'No pending ratings');
  String get allRatingsReviewedText => _t('Alle Bewertungen sind geprüft.', 'All ratings have been reviewed.');
  String get confirmApproveRatingTitle => _t('Bewertung freigeben?', 'Approve rating?');
  String get confirmRejectRatingTitle => _t('Bewertung ablehnen?', 'Reject rating?');
  String ratingApprovedBody(String raterName, String ratedName) => _t(
    'Die Bewertung von "$raterName" für "$ratedName" wird sichtbar und in den Durchschnitt gezählt.',
    'The rating from "$raterName" for "$ratedName" will become visible and count toward the average.',
  );
  String ratingRejectedBody(String raterName, String ratedName) => _t(
    'Die Bewertung von "$raterName" für "$ratedName" wird nicht angezeigt und nicht gezählt.',
    'The rating from "$raterName" for "$ratedName" will not be shown or counted.',
  );
  String get approveCheckLabel     => _t('Freigeben ✓', 'Approve ✓');
  String get ratingApprovedSnackbar => _t('Bewertung freigegeben ✓', 'Rating approved ✓');
  String get ratingRejectedSnackbar => _t('Bewertung abgelehnt', 'Rating rejected');
  String get approveButtonCaps     => _t('FREIGEBEN', 'APPROVE');
  String get pendingReviewBadge    => _t('AUSSTEHEND', 'PENDING');
  String get ratingForLabel        => _t('für', 'for');
  String get containsFlaggedLanguageWarning => _t('Enthält möglicherweise unangemessene Sprache', 'May contain inappropriate language');

  // ── Admin panel — flagged content moderation ───────────────────────────────────
  String get moderationTab         => _t('MODERATION', 'MODERATION');
  String get noPendingModerationTitle => _t('Keine gemeldeten Inhalte', 'No flagged content');
  String get allContentReviewedText => _t('Alle gemeldeten Inhalte sind geprüft.', 'All flagged content has been reviewed.');
  String get confirmApproveContentTitle => _t('Inhalt freigeben?', 'Approve content?');
  String get approveContentBody    => _t(
    'Der Inhalt wird wieder öffentlich sichtbar.',
    'The content will become publicly visible again.',
  );
  String get contentApprovedSnackbar => _t('Inhalt freigegeben ✓', 'Content approved ✓');
  String get flaggedPostingTypeLabel => _t('POSTING', 'POSTING');
  String get flaggedCompanyTypeLabel => _t('UNTERNEHMEN', 'COMPANY');
  String impersonationFlagNotice(String verifiedName) => _t(
      '⚠ Name ähnlich zu verifiziertem Unternehmen "$verifiedName" — möglicher Identitätsmissbrauch.',
      '⚠ Name similar to verified company "$verifiedName" — possible impersonation.');
  String duplicateVatFlagNotice(String otherCompanyName) => _t(
      '⚠ Diese USt-IdNr. wird bereits von "$otherCompanyName" verwendet.',
      '⚠ This VAT number is already used by "$otherCompanyName".');
  String get postingUnderReviewNotice => _t(
    'Ihr Inhalt wird derzeit geprüft und ist noch nicht öffentlich sichtbar.',
    'Your content is currently under review and not yet publicly visible.',
  );
  String get profileUnderReviewHidden => _t(
    'Ihr Unternehmensprofil wird geprüft und ist im Verzeichnis derzeit nicht sichtbar.',
    'Your company profile is under review and currently not visible in the directory.',
  );
  String get contentUnderReviewBadge => _t('IN PRÜFUNG', 'UNDER REVIEW');
  String get searchEllipsisHint   => _t('Suchen…', 'Search…');
  String get noResultsText        => _t('Keine Ergebnisse', 'No results');
  String get revokeVerificationTitle => _t('Verifizierung entziehen?', 'Revoke verification?');
  String revokeVerificationBody(String name) => _t(
    '"$name" verliert das VERIFIZIERT-Badge. Der Status wird auf "keiner" zurückgesetzt.',
    '"$name" will lose the VERIFIED badge. The status will be reset to "none".',
  );
  String get revokeButton         => _t('Entziehen', 'Revoke');
  String verificationRevokedSnackbar(String name) => _t('Verifizierung für $name entzogen', 'Verification revoked for $name');
  String get pendingBadgeCaps     => _t('AUSSTEHEND', 'PENDING');
  String get revokeVerificationTooltip => _t('Verifizierung entziehen', 'Revoke verification');

  // ── Company suspension (admin moderation consequence) ──────────────────────
  String get suspendCompanyTooltip => _t('Unternehmen sperren', 'Suspend company');
  String get suspendCompanyTitle  => _t('Unternehmen sperren?', 'Suspend company?');
  String suspendCompanyBody(String name) => _t(
    '"$name" kann keine neuen Anzeigen mehr veröffentlichen, und bestehende Anzeigen werden aus dem Feed entfernt.',
    '"$name" will no longer be able to publish new posts, and its existing posts will be removed from the feed.',
  );
  String get suspendReasonHint    => _t('Grund (wird dem Unternehmen angezeigt)', 'Reason (shown to the company)');
  String get suspendButton        => _t('Sperren', 'Suspend');
  String companySuspendedSnackbar(String name) => _t('$name gesperrt', '$name suspended');
  String get suspendedBadge       => _t('GESPERRT', 'SUSPENDED');
  String get unsuspendCompanyTooltip => _t('Sperre aufheben', 'Lift suspension');
  String get unsuspendCompanyTitle => _t('Sperre aufheben?', 'Lift suspension?');
  String unsuspendCompanyBody(String name) => _t(
    '"$name" kann wieder Anzeigen veröffentlichen; bestehende Anzeigen erscheinen wieder im Feed.',
    '"$name" will be able to publish posts again; its existing posts will reappear in the feed.',
  );
  String get unsuspendButton      => _t('Sperre aufheben', 'Lift suspension');
  String companyUnsuspendedSnackbar(String name) => _t('Sperre für $name aufgehoben', 'Suspension lifted for $name');
  String accountSuspendedPostBlocked(String reason) => _t(
    reason.isEmpty
        ? 'Ihr Unternehmen ist derzeit gesperrt und kann keine Anzeigen veröffentlichen.'
        : 'Ihr Unternehmen ist derzeit gesperrt und kann keine Anzeigen veröffentlichen. Grund: $reason',
    reason.isEmpty
        ? 'Your company is currently suspended and can\'t publish posts.'
        : 'Your company is currently suspended and can\'t publish posts. Reason: $reason',
  );

  // ── Forgot password ───────────────────────────────────────────────────────────
  String get emailSentTitle       => _t('E-Mail gesendet', 'Email sent');
  String get checkInboxInstructions => _t('Prüfen Sie Ihr Postfach und folgen Sie den Anweisungen.', 'Check your inbox and follow the instructions.');
  String get backToLoginButton    => _t('Zurück zur Anmeldung', 'Back to sign in');
  String get resetPasswordTitle   => _t('Passwort zurücksetzen', 'Reset password');
  String get sendLinkViaEmailText => _t('Wir senden Ihnen einen Link per E-Mail.', 'We will send you a link via email.');
  String get sendLinkButton       => _t('Link senden', 'Send link');

  // ── Admin-assisted onboarding ───────────────────────────────────────────────────
  String get onboardTab           => _t('ONBOARDING', 'ONBOARDING');
  String get onboardTabTitle      => _t('Unternehmen onboarden', 'Onboard a company');
  String get onboardIntroTitle    => _t('Telefon-Onboarding', 'Phone onboarding');
  String get onboardIntroBody     => _t(
    'Erstellen Sie während eines Anrufs ein Konto für ein Unternehmen, richten Sie das Profil ein und senden Sie einen Link zum Festlegen des Passworts.',
    'Create an account for a company during a call, set up their profile, and send them a link to set their password.',
  );
  String get onboardStartButton   => _t('Onboarding starten', 'Start onboarding');
  // Step 1 — account + basics
  String get onboardStep1Title    => _t('1. Konto & Eckdaten', '1. Account & basics');
  String get onboardStep1Subtitle => _t('E-Mail des Unternehmens und Basisdaten. Das Konto wird sofort erstellt.', 'Company email and basic details. The account is created immediately.');
  String get onboardEmailLabel    => _t('E-Mail des Unternehmens', 'Company email');
  String get onboardCompanyNameLabel => _t('Firmenname', 'Company name');
  String get onboardCreateAccountButton => _t('Konto erstellen', 'Create account');
  String get onboardAccountCreatedBanner => _t('Konto erstellt ✓', 'Account created ✓');
  // Step 2 — profile refinement
  String get onboardStep2Title    => _t('2. Profil vervollständigen', '2. Complete the profile');
  String get onboardStep2Subtitle => _t('Optional — während des Anrufs ausfüllen. Kann später ergänzt werden.', 'Optional — fill in during the call. Can be completed later.');
  String get onboardSaveProfileButton => _t('Profil speichern', 'Save profile');
  String get onboardProfileSavedSnackbar => _t('Profil gespeichert ✓', 'Profile saved ✓');
  // Step 3 — optional first post
  String get onboardStep3Title    => _t('3. Erste Anzeige (optional)', '3. First post (optional)');
  String get onboardStep3Subtitle => _t('Veröffentlichen Sie optional eine erste Kapazität für das Unternehmen.', 'Optionally publish a first capacity post for the company.');
  String get onboardAddFirstPostButton => _t('Erste Anzeige erstellen', 'Create first post');
  String get onboardSkipPostButton => _t('Ohne Anzeige fortfahren', 'Continue without a post');
  String get skipButton           => _t('Überspringen', 'Skip');
  String get onboardFirstPostDoneBanner => _t('Erste Anzeige veröffentlicht ✓', 'First post published ✓');
  // Step 4 — send invite
  String get onboardStep4Title    => _t('4. Einladung senden', '4. Send invitation');
  String get onboardStep4Subtitle => _t('Das Unternehmen erhält einen Link, um sein eigenes Passwort festzulegen und sich anzumelden.', 'The company receives a link to set their own password and sign in.');
  String onboardInviteSummary(String name, String email) => _t(
    'Einladung an $name ($email) senden.',
    'Send an invitation to $name ($email).',
  );
  String get onboardSendInviteButton => _t('Einladung senden', 'Send invitation');
  String get onboardInviteSentSnackbar => _t('Einladung gesendet ✓', 'Invitation sent ✓');
  String get onboardFinishButton  => _t('Fertig', 'Done');
  // Errors / states
  String get onboardEmailInUseError => _t(
    'Dieses Unternehmen hat bereits ein Konto. Bitte zur normalen Anmeldung / „Passwort vergessen" verweisen.',
    'This company already has an account. Direct them to normal sign-in / "forgot password" instead.',
  );
  String get onboardGenericError  => _t('Konto konnte nicht erstellt werden. Bitte erneut versuchen.', 'Could not create the account. Please try again.');
  // Tracking lists (admin tab)
  String get onboardNotInvitedSection => _t('Erstellt — noch nicht eingeladen', 'Created — not yet invited');
  String get onboardInvitedSection => _t('Eingeladen', 'Invited');
  String get onboardNoFollowupsText => _t('Keine offenen Onboardings', 'No pending onboardings');
  String get onboardSendInviteAction => _t('Einladung senden', 'Send invite');

  // ── Anonymized posts + gated contact requests ──────────────────────────────────
  String get requestContactButton => _t('Kontakt anfragen', 'Request contact');
  String get contactRequestSentSnackbar => _t('Anfrage gesendet — Kontakt wird vermittelt', 'Request sent — we\'ll broker the contact');
  String get contactRequestPendingNotice => _t('Anfrage gesendet. Wir vermitteln den Kontakt.', 'Request sent. We\'re brokering the contact.');
  String get completeProfileToRequestNotice => _t('Vervollständigen Sie Ihr Profil, um Kontakt anzufragen.', 'Complete your profile to request contact.');
  String get didItWorkOutPrompt   => _t('Hat\'s geklappt?', 'Did it work out?');
  String get outcomeMatchedLabel  => _t('Ja, vermittelt', 'Yes, matched');
  String get outcomeNoDealLabel   => _t('Kein Deal', 'No deal');
  String get thanksForFeedbackSnackbar => _t('Danke für dein Feedback', 'Thanks for your feedback');
  // Requester "Gesendete Anfragen" — matches navAnfragen exactly so the
  // sidebar label and this page's own title never disagree.
  String get myRequestsTitle      => _t('Gesendete Anfragen', 'Sent requests');
  String get noRequestsYetText    => _t('Noch keine Anfragen', 'No requests yet');
  String requestStatusLabel(String status) {
    switch (status) {
      case 'pending_review': return _t('In Prüfung', 'Under review');
      case 'pending':        return _t('Gesendet — wartet auf Anbieter', 'Sent — awaiting provider');
      case 'granted':        return _t('Freigeschaltet — Kontakt verfügbar', 'Unlocked — contact available');
      case 'declined':       return _t('Abgelehnt', 'Declined');
      case 'closed':         return _t('Geschlossen', 'Closed');
      default:               return _t('Ausstehend', 'Pending');
    }
  }
  // Compact variant for the tile chips on "Meine Anfragen".
  String requestStatusShort(String status) {
    switch (status) {
      case 'pending_review': return _t('In Prüfung', 'In review');
      case 'pending':        return _t('Gesendet', 'Sent');
      case 'granted':        return _t('Freigeschaltet', 'Unlocked');
      case 'declined':       return _t('Abgelehnt', 'Declined');
      case 'closed':         return _t('Geschlossen', 'Closed');
      default:               return _t('Ausstehend', 'Pending');
    }
  }
  // Admin "Kontaktanfragen" tab
  String get contactRequestsTab   => _t('ANFRAGEN', 'REQUESTS');
  String get noContactRequestsText => _t('Keine Kontaktanfragen', 'No contact requests');
  String get requesterLabel       => _t('Anfragender', 'Requester');
  String get posterLabel          => _t('Anbieter', 'Poster');
  String get outcomeFieldLabel    => _t('Ergebnis', 'Outcome');
  String get valueEstimateLabel   => _t('Wert', 'Value');
  String get valueHochLabel       => _t('Hoch', 'High');
  String get valueMittelLabel     => _t('Mittel', 'Medium');
  String get valueNiedrigLabel    => _t('Niedrig', 'Low');
  String get brokerButton         => _t('Vermitteln', 'Broker');
  String get grantButton          => _t('Freigeben', 'Grant');
  String get posterUnresolvedLabel => _t('— (öffnen zum Auflösen)', '— (open to resolve)');

  // ── Nachricht senden (free message-first contact) ───────────────────────────
  String get sendInterestButton   => _t('Nachricht senden', 'Send message');
  String get interestSentButton   => _t('Nachricht gesendet', 'Message sent');
  String get messageComposerSubtitle => _t(
      'Ihre Nachricht geht anonym an das Unternehmen. Ihr Name wird erst sichtbar, wenn es Ihre Anfrage annimmt.',
      'Your message is sent anonymously. Your name is revealed only once they accept your request.');
  String get messageSentSnackbar => _t('Nachricht gesendet', 'Message sent');
  String get messageSentTitle    => _t('Nachricht gesendet', 'Message sent');
  String get messageSentBody     => _t(
      'Das Unternehmen wurde benachrichtigt und meldet sich in Kürze. Den Status sehen Sie unter „Meine Anfragen".',
      'The company has been notified and will get back to you shortly. You can track the status under "My requests".');
  String get messageDeclinedTitle => _t('Anfrage abgelehnt', 'Request declined');
  String get messageDeclinedBody  => _t(
      'Das Unternehmen hat diese Anfrage leider abgelehnt. Schauen Sie sich weitere Kapazitäten im Feed an.',
      'The company declined this request. Have a look at other capacity in the feed.');
  String get interestModalSubtitle => _t(
      'Mit einer Vermittlung schalten Sie Firma, Kontakt und Chat sofort frei.',
      'One connection instantly unlocks the company, contact and chat.');
  String get interestSummaryLabel => _t('Kapazität', 'Capacity');
  String get interestMessageLabel => _t('Nachricht (optional)', 'Message (optional)');
  String get interestMessageHint  => _t('Kurz zum Projekt – ohne Kontaktdaten', 'Briefly about the project – no contact details');
  String get interestSendConfirm  => _t('Anfrage senden', 'Send request');
  String get interestContainsContactWarning => _t(
      'Telefonnummern und E-Mail-Adressen sind hier nicht erlaubt und werden automatisch abgelehnt — der Kontakt wird nach der Verbindung automatisch freigegeben. Bitte entfernen, um zu senden.',
      'Phone numbers and email addresses aren\'t allowed here and are rejected automatically — contact is shared automatically once you\'re connected. Please remove it to send.');
  String get markUrgentLabel => _t(
      'Dringend – ich brauche schnell eine Antwort',
      'Urgent – I need a quick reply');
  String get urgentRequestBadge => _t('DRINGEND', 'URGENT');

  // ── Vermittlungen (credit-based instant reveal) ─────────────────────────────
  String vermittlungRemaining(int x, int y) =>
      _t('Verbleibende Vermittlungen: $x von $y', 'Connections left: $x of $y');
  String get vermittlungConfirmSubtitle => _t(
      'Nach dem Einsatz einer Vermittlung wird die Anzeige sofort freigeschaltet.',
      'Using one connection unlocks this post instantly.');
  String get vermittlungUnlocksTitle => _t('Sie erhalten sofort Zugriff auf:', 'You instantly unlock:');
  String get unlockCompanyName => _t('Firmenname', 'Company name');
  String get unlockContact     => _t('Telefon & E-Mail', 'Phone & email');
  String get unlockChat        => _t('Direktnachrichten', 'Direct messages');
  String get vermittlungSpendButton => _t('Vermittlung einsetzen', 'Use a connection');
  String get vermittlungNoneLeft => _t('Diesen Monat keine Vermittlungen mehr übrig.', 'No connections left this month.');
  String get vermittlungStaleNotice => _t(
      'Diese Anzeige ist über 30 Tage alt – zum Schutz Ihrer Vermittlung gesperrt.',
      'This post is over 30 days old — locked to protect your connection.');
  String get vermittlungUnlockedTitle => _t('Freigeschaltet', 'Unlocked');
  String get vermittlungUnlockedSubtitle =>
      _t('Sie können jetzt direkt Kontakt aufnehmen.', 'You can now get in touch directly.');
  String get ownPostTitle => _t('Ihre eigene Anzeige', 'Your own post');
  String get ownPostBody => _t(
      'Das ist Ihre eigene Kapazität – eine Vermittlung ist hier nicht nötig.',
      'This is your own capacity — no connection needed here.');
  String get vermittlungPendingReviewTitle => _t('In Prüfung', 'Under review');
  String get vermittlungPendingReviewBody => _t(
      'Ihr Unternehmen wird verifiziert. Sobald das erledigt ist, wird die Vermittlung automatisch freigeschaltet.',
      'We\'re verifying your company. Once done, this connection unlocks automatically.');
  String get vermittlungSentSnackbar => _t('Freigeschaltet', 'Unlocked');
  String get vermittlungPendingSnackbar => _t('Anfrage in Prüfung', 'Request under review');
  // Sidebar + inbox
  String creditsPill(int x) => _t('$x Vermittlungen', '$x connections');
  String get receivedVermittlungenTitle => _t('Vermittlungen', 'Connections');
  String get receivedVermittlungenNav => _t('Vermittlungen', 'Connections');
  String nameChangeCooldownError(int days) => _t(
      'Der Firmenname kann nur alle $days Tage geändert werden.',
      'The company name can only be changed every $days days.');
  String get websiteOptionalLabel => _t('Website (optional)', 'Website (optional)');
  String get netzwerkGroupLabel => _t('Mein Netzwerk', 'My network');
  String get navAnzeigen => _t('Anzeigen', 'Listings');
  // Previously 'Anfragen'/'Kontakte' — neither said which DIRECTION the
  // requests go, and 'Kontakte' (Contacts) actively misled: it opens the
  // received-requests inbox (Accept/Decline), not an address book of
  // established connections. Renamed as an explicit sent/received pair,
  // matching the page titles inside exactly (myRequestsTitle /
  // receivedRequestsTitle) so the sidebar and the page never disagree.
  String get navAnfragen => _t('Gesendete Anfragen', 'Sent requests');
  String get navKontakte => _t('Erhaltene Anfragen', 'Received requests');
  String get noVermittlungenYet => _t('Noch keine Vermittlungen zu Ihren Anzeigen', 'No connections to your posts yet');
  String receivedUnlockedFrom(String city) => city.isEmpty
      ? _t('Ein Unternehmen hat Ihre Anzeige freigeschaltet', 'A company unlocked your post')
      : _t('Ein Unternehmen aus $city hat Ihre Anzeige freigeschaltet', 'A company from $city unlocked your post');
  // Follow-up
  String get outcomeOpenLabel => _t('Noch offen', 'Still open');
  // One-word outcome answers for the compact tiles ("Hat's geklappt?" → Ja/Offen/Nein).
  String get outcomeYesShort  => _t('Ja', 'Yes');
  String get outcomeOpenShort => _t('Offen', 'Open');
  String get outcomeNoShort   => _t('Nein', 'No');
  // Admin
  String get approveGrantButton => _t('Freigeben & vermitteln', 'Approve & connect');

  // ── Trust block (detail, no identity) ───────────────────────────────────────
  String get trustBlockTitle      => _t('Vertrauen', 'Trust');
  String get trustVerifiedCompany => _t('Verifiziertes Unternehmen', 'Verified company');
  String get trustUnverifiedCompany => _t('Noch nicht verifiziert', 'Not yet verified');
  String trustRatingSummary(String avg, int count) =>
      _t('$avg · $count Bewertungen', '$avg · $count reviews');
  String get trustNoRatingsYet    => _t('Noch keine Bewertungen', 'No reviews yet');
  String get trustIdentityHiddenNote => _t(
      'Der Firmenname ist ausgeblendet. Mit einer Vermittlung schalten Sie Firma, Kontakt und Chat sofort frei.',
      'The company name is hidden. One connection instantly unlocks the company, contact and chat.');
  String get anonExplainerBannerBody => _t(
      'Firmennamen sind anonymisiert. Senden Sie eine Nachricht — sobald die Firma antwortet, sehen Sie Name, Kontakt und Chat.',
      'Company names are anonymized. Send a message — once the company replies, you\'ll see their name, contact, and chat.');

  // ── Erhaltene Anfragen (poster inbox) ───────────────────────────────────────
  String get receivedRequestsTitle => _t('Erhaltene Anfragen', 'Received requests');
  String get receivedRequestsNavLabel => _t('Erhaltene Anfragen', 'Received requests');
  String get noReceivedRequestsText => _t('Noch keine Anfragen zu Ihren Anzeigen', 'No requests for your posts yet');
  String receivedRequestFrom(String city) => city.isEmpty
      ? _t('Ein Bauunternehmen', 'A construction company')
      : _t('Ein Bauunternehmen aus $city', 'A construction company from $city');
  String receivedRequestVerifiedFrom(String city) => city.isEmpty
      ? _t('Ein verifiziertes Bauunternehmen', 'A verified construction company')
      : _t('Ein verifiziertes Bauunternehmen aus $city', 'A verified construction company from $city');
  String get receivedRequestForPostLabel => _t('Zu Ihrer Anzeige', 'For your post');
  String get receivedRequestMessageLabel => _t('Nachricht', 'Message');
  String get acceptRequestButton  => _t('Akzeptieren', 'Accept');
  String get declineRequestButton => _t('Ablehnen', 'Decline');
  String get requestAcceptedSnackbar => _t('Angenommen — Kontakt freigegeben', 'Accepted — contact shared');
  String get requestDeclinedSnackbar => _t('Anfrage abgelehnt', 'Request declined');
  String get requestContactRevealedTitle => _t('Kontakt freigegeben', 'Contact shared');
  String get receivedStatusPendingLabel => _t('Wartet auf Ihre Antwort', 'Awaiting your response');
  String get receivedStatusGrantedLabel => _t('Angenommen', 'Accepted');
  String get receivedStatusDeclinedLabel => _t('Abgelehnt', 'Declined');

  // ── In-app messaging ────────────────────────────────────────────────────────
  String get messagesInboxTitle   => _t('Nachrichten', 'Messages');
  String get messagesNavLabel     => _t('Nachrichten', 'Messages');
  String get sendMessageButton    => _t('Nachricht senden', 'Send message');
  String get openChatButton       => _t('Chat öffnen', 'Open chat');
  String get messageHint          => _t('Nachricht schreiben …', 'Write a message …');
  String get noMessagesYet        => _t('Noch keine Nachrichten – schreiben Sie die erste.', 'No messages yet — send the first one.');
  String get noMessagesYetShort   => _t('Noch keine Nachrichten', 'No messages yet');
  String get noChatsYet           => _t('Noch keine Unterhaltungen. Nach einer angenommenen Anfrage können Sie hier chatten.', 'No conversations yet. Once a request is accepted you can chat here.');
  String get chatFallbackTitle    => _t('Unternehmen', 'Company');
  String get typingLabel          => _t('tippt …', 'typing …');
  String get seenReceipt          => _t('Gelesen', 'Seen');
  String get deliveredReceipt     => _t('Zugestellt', 'Delivered');
  String get dateTodayLabel       => _t('Heute', 'Today');
  String get dateYesterdayLabel   => _t('Gestern', 'Yesterday');
  String get messageBlockedSnackbar => _t('Nachricht enthält unzulässige Sprache und wurde nicht gesendet.', 'Message contains disallowed language and was not sent.');

  // ── Admin one-off legacy migration ──────────────────────────────────────────
  String get migrateLegacyTooltip => _t('Alt-Anzeigen migrieren', 'Migrate legacy posts');
  String get migrateLegacyTitle   => _t('Alt-Anzeigen migrieren', 'Migrate legacy posts');
  String get migrateLegacyConfirm => _t(
      'Entfernt Firmenname/Telefon/E-Mail aus allen alten öffentlichen Anzeigen, legt die geschützten Kontakt-Datensätze an, ergänzt Vertrauenssignale und vereinheitlicht alte Gewerke. Einmalig und wiederholbar (bereits migrierte werden übersprungen).',
      'Removes company name/phone/email from all old public posts, creates the locked contact records, backfills trust signals, and normalizes legacy trades. One-off and safe to re-run (already-migrated posts are skipped).');
  String get migrateLegacyRun     => _t('Migration starten', 'Run migration');
  String migrateLegacyResult(int migrated, int skipped, int failed) => _t(
      'Migriert: $migrated · übersprungen: $skipped · Fehler: $failed',
      'Migrated: $migrated · skipped: $skipped · failed: $failed');

  // ── Admin extensions (pre-screening + repeat signal) ────────────────────────
  String get approveForPosterButton => _t('Für Anbieter freigeben', 'Release to provider');
  String postsFromCompany(int n) => _t(
      '$n ${n == 1 ? 'Anzeige' : 'Anzeigen'} dieser Firma',
      '$n ${n == 1 ? 'post' : 'posts'} by this company');
  String get requesterMessageLabel => _t('Nachricht des Anfragenden', 'Requester\'s message');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['de', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
