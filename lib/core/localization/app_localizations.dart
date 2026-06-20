import 'package:flutter/material.dart';
import '../models/report_model.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  bool get isEn => locale.languageCode == 'en';
  String _t(String de, String en) => isEn ? en : de;

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
  String get days            => _t('Tage', 'days');
  String get active          => _t('aktiv', 'active');

  // ── Landing navbar ──────────────────────────────────────────────────────────
  String get navAbout           => _t('Über uns', 'About');
  String get navLogin           => 'Login';
  String get navStartFree       => _t('Kostenlos starten', 'Get started');
  String get navStartFreeMobile => 'Start';

  // ── Hero ────────────────────────────────────────────────────────────────────
  String get heroLiveBadge   => _t('31 neue Kapazitäten · heute live', '31 new capacities · live today');
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
  String get heroStatTrades   => _t('11 Gewerke', '11 trades');

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

  // ── Activity demo data ───────────────────────────────────────────────────────
  String get activity1   => _t('Elektriker in Hamburg – sofort',           'Electricians in Hamburg – now');
  String get activity2   => _t('Dachdecker für Projekt gesucht',           'Roofers needed for project');
  String get activity3   => _t('Trockenbauer – Altona · nächste Woche',    'Drywallers – Altona · next week');

  // ── Stats bar ────────────────────────────────────────────────────────────────
  String get stat1Label  => _t('Aktive Unternehmen', 'Active Companies');
  String get stat2Label  => _t('Verfügbar heute',    'Available today');
  String get stat3Label  => _t('Gesuche heute',      'Needs today');
  String get stat4Label  => _t('Ø Antwortzeit',      'Ø Response time');

  // ── How it works ─────────────────────────────────────────────────────────────
  String get howTitle    => _t('Wie es funktioniert',                    'How it works');
  String get howSubtitle => _t('In drei Schritten zur ersten Verbindung.', 'Three steps to your first connection.');
  String get step1Title  => _t('Kapazität veröffentlichen',              'Post your capacity');
  String get step1Desc   => _t(
    'Teilen Sie in 30 Sekunden mit, welche Teams verfügbar sind oder welche Sie suchen.',
    'In 30 seconds, share which teams are available or which you are looking for.',
  );
  String get step2Title  => _t('Passende Unternehmen finden',            'Find matching companies');
  String get step2Desc   => _t(
    'Entdecken Sie sofort, wer Ihre Anforderungen erfüllt – nach Gewerk, Ort und Datum.',
    'Instantly discover who meets your requirements – by trade, location, and date.',
  );
  String get step3Title  => _t('Direkt Kontakt aufnehmen',               'Contact directly');
  String get step3Desc   => _t(
    'Telefonieren oder mailen Sie direkt – ohne Mittelsmann, ohne Gebühren.',
    'Call or email directly – no middleman, no fees.',
  );

  // ── Activity section ─────────────────────────────────────────────────────────
  String get activityTitle    => _t('Aktuelle Aktivität',                               'Recent Activity');
  String get activitySubtitle => _t('Echte Posts von echten Unternehmen — gerade eben.', 'Real posts from real companies — just now.');

  // ── Network section ──────────────────────────────────────────────────────────
  String get networkTitle      => _t('Fokussiert auf Hamburg',                                              'Focused on Hamburg');
  String get networkSubtitle   => _t('Alle 15 Stadtteile abgedeckt — von Altona bis Bergedorf.',             'All 15 districts covered — from Altona to Bergedorf.');
  String get networkFactDistricts => _t('Stadtteile', 'Districts');
  String get networkFactTrades    => _t('Gewerke', 'Trades');
  String get networkFactLive      => _t('Echtzeit-Feed', 'Real-time feed');
  String get networkFactLiveValue => _t('Live', 'Live');

  // ── Trust section ────────────────────────────────────────────────────────────
  String get trustTitle    => _t('Vertrauen & Sicherheit',              'Trust & Safety');
  String get trustSubtitle => _t('Nur echte Bauunternehmen. Keine Anonymität.', 'Only real construction companies. No anonymity.');
  String get trust1Title   => _t('Verifiziert',    'Verified');
  String get trust1Desc    => _t('Geprüfte Unternehmensprofile',            'Verified company profiles');
  String get trust2Title   => _t('Bewertet',       'Rated');
  String get trust2Desc    => _t('Transparente Ratings nach jedem Auftrag', 'Transparent ratings after every job');
  String get trust3Title   => _t('Blitzschnell',   'Lightning fast');
  String get trust3Desc    => _t('Ø Antwortzeit unter 2 Stunden',           'Ø Response time under 2 hours');
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
  String get loginLiveBadge   => 'LIVE · Hamburg · 50 km Radius';
  String get emailLabel       => 'E-Mail';
  String get passwordLabel    => _t('Passwort',           'Password');
  String get forgotPassword   => _t('Passwort vergessen?', 'Forgot password?');
  String get loginButton      => _t('ANMELDEN',  'SIGN IN');
  String get loginEnterHint   => _t('oder ENTER drücken', 'or press ENTER');
  String get noAccount        => _t('Noch kein Konto? ',  'No account? ');
  String get registerLink     => _t('Registrieren',       'Register');
  String get invalidEmail     => _t('Ungültige E-Mail',   'Invalid email');

  // ── Register ─────────────────────────────────────────────────────────────────
  String get registerTitle    => _t('Konto erstellen',               'Create account');
  String get registerSubtitle => _t('Werden Sie Teil der Kapazitätsbörse.', 'Join the capacity exchange.');
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
  String get cityHint         => 'Hamburg';
  String get phoneLabel       => _t('Telefon',            'Phone');
  String get phoneHint        => '+49 40 123456';
  String get companyEmailLabel => _t('Unternehmens-E-Mail *', 'Company email *');
  String get companyEmailHint  => _t('info@mustermann-gmbh.de', 'info@company.com');
  String get websiteLabel     => 'Website';
  String get sectionVerify    => _t('VERIFIZIERUNG', 'VERIFICATION');
  String get vatLabel         => _t('Umsatzsteuer-ID (USt-IdNr.)', 'VAT number');
  String get vatHint          => 'DE123456789';
  String get vatError         => _t('Format: DE + 9 Ziffern (z.B. DE123456789)', 'Format: DE + 9 digits (e.g. DE123456789)');
  String get verifyHowTitle   => _t('Wie die Verifizierung funktioniert', 'How verification works');
  String get verifySteps      => _t(
    '1. Geben Sie Ihre USt-IdNr. ein\n'
    '2. Senden Sie eine Kopie Ihres Steuerdokuments an: verifizierung@capacify.de\n'
    '3. Nach Prüfung erhalten Sie das ✓ VERIFIZIERT Badge auf Ihrem Profil',
    '1. Enter your VAT number\n'
    '2. Send a copy of your tax document to: verifizierung@capacify.de\n'
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
  String get navAnalytics    => 'Analytics';
  String get comingSoonTag   => _t('Bald verfügbar', 'Coming soon');
  String get navPostCapacity => _t('Kapazität posten', 'Post Capacity');
  String get sidebarFeedback => _t('Feedback geben',  'Give feedback');
  String get sidebarQuote    => _t('"Wo Angebot und Bedarf\nzusammenkommen."', '"Where supply and demand meet."');

  // ── Dashboard topbar ─────────────────────────────────────────────────────────
  String get menuProfile      => _t('Mein Profil',       'My Profile');
  String get menuCompany      => _t('Mein Unternehmen',  'My Company');
  String get menuSettings     => _t('Einstellungen',     'Settings');
  String get menuLogout       => _t('Abmelden',          'Sign out');
  String get topBarTitle      => _t('LIVE KAPAZITÄTSBÖRSE', 'LIVE CAPACITY EXCHANGE');
  String get topBarSubtitle   => 'Hamburg · 50 km Radius';
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
      case 'Generalunternehmer': return 'General Contractor';
      case 'Rohbau': return 'Shell Construction';
      case 'Trockenbau': return 'Drywall';
      case 'Elektro': return 'Electrical';
      case 'Sanitär & Heizung': return 'Plumbing & Heating';
      case 'Dach': return 'Roofing';
      case 'Fassade': return 'Facade';
      case 'Tiefbau': return 'Civil Engineering';
      case 'Architektur': return 'Architecture';
      case 'Statik': return 'Structural Engineering';
      case 'Stahl': return 'Steel';
      case 'Beton': return 'Concrete';
      case 'HVAC': return 'HVAC';
      case 'Lieferant': return 'Supplier';
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

  // ── Live feed ─────────────────────────────────────────────────────────────────
  String get tabAll              => _t('ALLE', 'ALL');
  String get feedSearchHint      => _t('Gewerk, Ort oder Unternehmen...', 'Trade, location or company...');
  String get sortNearestFirst    => _t('Nächste zuerst', 'Nearest first');
  String get whenLabel           => _t('Wann', 'When');
  String get whenAllTimes        => _t('Alle Zeiten', 'All times');
  String get whenNow             => _t('Sofort verfügbar', 'Available now');
  String get whenThisWeek        => _t('Diese Woche', 'This week');
  String get whenNextWeek        => _t('Nächste Woche', 'Next week');
  String get tradeFilterLabel    => _t('Gewerk', 'Trade');
  String get feedEmptyTitle      => _t('Keine Kapazitäten', 'No capacities');
  String get feedEmptySubtitle   => _t(
    'Passen Sie die Filter an\noder posten Sie eine neue Kapazität.',
    'Adjust the filters\nor post a new capacity.',
  );
  String get loadMoreButton      => _t('Mehr laden', 'Load more');
  String errorWithMessage(Object e) => _t('Fehler: $e', 'Error: $e');
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
  String copyTooltip(String label) => _t('$label kopieren', 'Copy $label');

  // ── Company profile (Unternehmensprofil) ─────────────────────────────────────
  String get profileSavedSuccess => _t('Profil erfolgreich gespeichert.', 'Profile saved successfully.');
  String get saveErrorRetry      => _t('Fehler beim Speichern. Bitte erneut versuchen.', 'Error saving. Please try again.');
  String get companyProfileTitle    => _t('Unternehmensprofil', 'Company Profile');
  String get companyProfileSubtitle => _t('Präsentieren Sie Ihr Unternehmen auf Capacify', 'Present your company on Capacify');
  String get basicInfoSection     => _t('Grundinformationen', 'Basic Information');
  String get tradeBranchLabel     => _t('Gewerk / Branche *', 'Trade / Industry *');
  String get descriptionRequiredLabel => _t('Beschreibung *', 'Description *');
  String get describeCompanyHint  => _t('Beschreiben Sie Ihr Unternehmen...', 'Describe your company...');
  String get contactInfoSection   => _t('Kontaktinformationen', 'Contact Information');
  String get websiteHint          => _t('https://www.ihre-firma.de', 'https://www.your-company.com');
  String get locationSection      => _t('Standort', 'Location');
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
  String get section2Trade        => _t('2. Gewerk auswählen', '2. Select trade');
  String get section3When         => _t('3. Wann verfügbar?', '3. When available?');
  String get availNowAllCaps      => _t('SOFORT VERFÜGBAR', 'AVAILABLE NOW');
  String get availableFromTodaySubtitle => _t('Ab heute einsetzbar', 'Can start today');
  String get within7DaysSubtitle  => _t('Innerhalb der nächsten 7 Tage', 'Within the next 7 days');
  String get in7to14DaysSubtitle  => _t('In 7-14 Tagen verfügbar', 'Available in 7-14 days');
  String get chooseDateLabel      => _t('Zeitraum wählen', 'Choose date range');
  String get chooseDateFromCalendar => _t('Zeitraum aus Kalender wählen', 'Choose date range from calendar');
  String get startDateChip       => _t('Start', 'Start');
  String get endDateChip         => _t('Ende', 'End');
  String get section4LocationHamburg => _t('4. Standort in Hamburg', '4. Location in Hamburg');
  String get section5WorkerCount  => _t('5. Anzahl Personen', '5. Number of people');
  String get section6Description  => _t('6. Beschreibung', '6. Description');
  String get descriptionExampleHint => _t(
    'z.B. "5 Trockenbauer ab Montag, alle Werkzeuge dabei, Führerschein vorhanden..."',
    'e.g. "5 drywall workers from Monday, all tools included, driver\'s license available..."',
  );
  String get previewLabel         => _t('Vorschau', 'Preview');
  String get postNowButton        => _t('Jetzt posten', 'Post now');

  // ── Edit capacity ─────────────────────────────────────────────────────────────
  String get capacityUpdatedSuccess => _t('Kapazität aktualisiert.', 'Capacity updated.');
  String get saveErrorGeneric     => _t('Fehler beim Speichern.', 'Error saving.');
  String get editCapacityTitle    => _t('Kapazität bearbeiten', 'Edit Capacity');
  String get endedBadge           => _t('BEENDET', 'ENDED');
  String get titleRequiredLabel   => _t('Titel *', 'Title *');
  String get locationRequiredLabel => _t('Ort *', 'Location *');
  String get countRequiredLabel   => _t('Anzahl *', 'Count *');
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
  String rateCompanyDialogTitle(String companyName) => _t('$companyName bewerten', 'Rate $companyName');
  String get yourRatingLabel      => _t('Ihre Bewertung', 'Your rating');
  String get commentOptionalLabel => _t('Kommentar (optional)', 'Comment (optional)');
  String get commentOptionalHint  => _t('Wie war die Zusammenarbeit?', 'How was working with them?');
  String get submitRatingButton   => _t('Bewertung abschicken', 'Submit rating');
  String get ratingSubmittedSuccess => _t('Bewertung gespeichert', 'Rating saved');
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
  String get emailNotificationsSubtitle => _t('Updates per E-Mail erhalten', 'Receive updates via email');
  String get newCapacitiesTitle   => _t('Neue Kapazitäten', 'New capacities');
  String get newPostingsSubtitle  => _t('Benachrichtigung bei neuen Postings', 'Notification for new postings');
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
  String get overviewTab          => _t('ÜBERSICHT', 'OVERVIEW');
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

  // ── Forgot password ───────────────────────────────────────────────────────────
  String get emailSentTitle       => _t('E-Mail gesendet', 'Email sent');
  String get checkInboxInstructions => _t('Prüfen Sie Ihr Postfach und folgen Sie den Anweisungen.', 'Check your inbox and follow the instructions.');
  String get backToLoginButton    => _t('Zurück zur Anmeldung', 'Back to sign in');
  String get resetPasswordTitle   => _t('Passwort zurücksetzen', 'Reset password');
  String get sendLinkViaEmailText => _t('Wir senden Ihnen einen Link per E-Mail.', 'We will send you a link via email.');
  String get sendLinkButton       => _t('Link senden', 'Send link');
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
