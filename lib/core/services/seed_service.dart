import 'package:cloud_firestore/cloud_firestore.dart';

class SeedService {
  final _db = FirebaseFirestore.instance;
  static const _demoPrefix = 'demo_company_0';

  Future<bool> isDemoSeeded() async {
    final doc = await _db.collection('companies').doc('${_demoPrefix}1').get();
    return doc.exists;
  }

  Future<void> seedAll() async {
    await _seedCompanies();
    await _seedCapacities();
    await seedRatings();
  }

  Future<void> clearDemoData() async {
    final companyIds = List.generate(6, (i) => '$_demoPrefix${i + 1}');
    final companyBatch = _db.batch();
    for (final id in companyIds) {
      companyBatch.delete(_db.collection('companies').doc(id));
    }
    await companyBatch.commit();

    final snaps = await _db
        .collection('capacities')
        .where('companyId', whereIn: companyIds)
        .get();
    if (snaps.docs.isNotEmpty) {
      final capBatch = _db.batch();
      for (final doc in snaps.docs) {
        capBatch.delete(doc.reference);
      }
      await capBatch.commit();
    }

    final ratingSnaps = await _db
        .collection('companyRatings')
        .where('companyId', whereIn: companyIds)
        .get();
    if (ratingSnaps.docs.isEmpty) return;
    final ratingBatch = _db.batch();
    for (final doc in ratingSnaps.docs) {
      ratingBatch.delete(doc.reference);
    }
    await ratingBatch.commit();
  }

  // ── Ratings ──────────────────────────────────────────
  //
  // The 6 demo companies rate each other (as if they'd worked together
  // before) so the seeded posts/companies show realistic-looking reviews
  // instead of an empty "no ratings yet" state. Deterministic doc IDs
  // (raterId_ratedId) make this safe to re-run without duplicating.

  Future<void> seedRatings() async {
    const names = {
      '${_demoPrefix}1': 'Müller Trockenbau GmbH (Beispiel)',
      '${_demoPrefix}2': 'Hamburg Rohbau AG (Beispiel)',
      '${_demoPrefix}3': 'Elbe Elektrotechnik GmbH (Beispiel)',
      '${_demoPrefix}4': 'Hanseatische Dachbau KG (Beispiel)',
      '${_demoPrefix}5': 'Nord-Tiefbau GmbH & Co. KG (Beispiel)',
      '${_demoPrefix}6': 'Alster Sanierung GmbH (Beispiel)',
    };

    // (raterId, ratedId, stars, comment, daysAgo)
    final ratings = <(String, String, int, String, int)>[
      ('${_demoPrefix}2', '${_demoPrefix}1', 5, 'Pünktlich, saubere Arbeit, jederzeit wieder.', 3),
      ('${_demoPrefix}3', '${_demoPrefix}1', 4, 'Gute Kommunikation, kleine Verzögerung beim Start.', 9),
      ('${_demoPrefix}4', '${_demoPrefix}1', 5, 'Top Qualität bei den Spachtelarbeiten.', 16),

      ('${_demoPrefix}1', '${_demoPrefix}2', 5, 'Zuverlässige Kolonne, termingerecht fertig.', 4),
      ('${_demoPrefix}5', '${_demoPrefix}2', 4, 'Solide Arbeit, Material kam leicht verspätet.', 11),
      ('${_demoPrefix}6', '${_demoPrefix}2', 5, 'Sehr professionell, gerne wieder.', 20),

      ('${_demoPrefix}1', '${_demoPrefix}3', 5, 'Saubere Verkabelung, sehr empfehlenswert.', 5),
      ('${_demoPrefix}4', '${_demoPrefix}3', 5, 'Schnelle Reaktion, faire Preise.', 13),
      ('${_demoPrefix}6', '${_demoPrefix}3', 4, 'Gute Arbeit, etwas teurer als erwartet.', 22),

      ('${_demoPrefix}2', '${_demoPrefix}4', 4, 'Gute Dachdecker, kleine Nacharbeit nötig.', 7),
      ('${_demoPrefix}5', '${_demoPrefix}4', 5, 'Top Truppe, sehr zuverlässig.', 18),

      ('${_demoPrefix}2', '${_demoPrefix}5', 5, 'Maschinenpark top, schnelle Erdarbeiten.', 6),
      ('${_demoPrefix}4', '${_demoPrefix}5', 3, 'Ok, aber Kommunikation könnte besser sein.', 14),
      ('${_demoPrefix}6', '${_demoPrefix}5', 5, 'Sehr zuverlässig, jederzeit wieder.', 25),

      ('${_demoPrefix}1', '${_demoPrefix}6', 5, 'Hervorragende Sanierungsarbeit, Denkmalschutz-Erfahrung merkt man.', 8),
      ('${_demoPrefix}3', '${_demoPrefix}6', 4, 'Gute Truppe, Projekt etwas verzögert.', 17),
      ('${_demoPrefix}5', '${_demoPrefix}6', 5, 'Sehr kompetent, klare Empfehlung.', 28),
    ];

    final now = DateTime.now();
    final batch = _db.batch();
    final sums = <String, int>{};
    final counts = <String, int>{};

    for (final (raterId, ratedId, stars, comment, daysAgo) in ratings) {
      final ts = Timestamp.fromDate(now.subtract(Duration(days: daysAgo)));
      final ref = _db.collection('companyRatings').doc('${raterId}_$ratedId');
      batch.set(ref, {
        'raterUserId': raterId,
        'raterCompanyName': names[raterId],
        'companyId': ratedId,
        'ratedCompanyName': names[ratedId],
        'rating': stars,
        'comment': comment,
        'status': 'approved',
        'createdAt': ts,
        'updatedAt': ts,
      });
      sums[ratedId] = (sums[ratedId] ?? 0) + stars;
      counts[ratedId] = (counts[ratedId] ?? 0) + 1;
    }

    for (final companyId in sums.keys) {
      batch.update(_db.collection('companies').doc(companyId), {
        'ratingSum': sums[companyId],
        'ratingCount': counts[companyId],
      });
    }

    await batch.commit();
  }

  // ── Companies ────────────────────────────────────────

  Future<void> _seedCompanies() async {
    final batch = _db.batch();
    for (final c in _companies()) {
      final id = c['id'] as String;
      final data = Map<String, dynamic>.from(c)..remove('id');
      data['createdAt'] = FieldValue.serverTimestamp();
      batch.set(_db.collection('companies').doc(id), data);
    }
    await batch.commit();
  }

  // ── Capacities ───────────────────────────────────────

  Future<void> _seedCapacities() async {
    final caps = _capacities();
    // Firestore batch limit is 500; 20 items is fine
    final batch = _db.batch();
    for (final c in caps) {
      batch.set(_db.collection('capacities').doc(), c);
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────
  //  COMPANY DATA
  // ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _companies() {
    return [
      {
        'id': '${_demoPrefix}1',
        'ownerId': '${_demoPrefix}1',
        'name': 'Müller Trockenbau GmbH (Beispiel)',
        'description':
            'Spezialisierter Trockenbau- und Innenausbau-Betrieb mit 12 Jahren Erfahrung im Hamburger Raum. Gipskarton, abgehängte Decken und Akustikwände.',
        'website': 'www.mueller-trockenbau-demo.de',
        'email': 'info@mueller-trockenbau-demo.de',
        'phone': '+49 40 1234567',
        'address': 'Stresemannstraße 45',
        'city': 'Hamburg',
        'postalCode': '22769',
        'country': 'Deutschland',
        'employees': '11-50',
        'trade': 'Trockenbau',
        'services': ['Trockenbau', 'Innenausbau', 'Akustikdecken', 'Spachtelarbeiten'],
        'logoUrl': '',
        'vatNumber': 'DE112233445',
        'verificationStatus': 'verified',
      },
      {
        'id': '${_demoPrefix}2',
        'ownerId': '${_demoPrefix}2',
        'name': 'Hamburg Rohbau AG (Beispiel)',
        'description':
            'Rohbau-Spezialist für Wohn- und Gewerbebau. Schlüsselfertige Rohbauprojekte, Mauerwerk und Betonarbeiten im Großraum Hamburg seit 1998.',
        'website': 'www.hamburg-rohbau-demo.de',
        'email': 'projekte@hamburg-rohbau-demo.de',
        'phone': '+49 40 9876543',
        'address': 'Billhorner Röhrendamm 12',
        'city': 'Hamburg',
        'postalCode': '20539',
        'country': 'Deutschland',
        'employees': '51-200',
        'trade': 'Rohbau',
        'services': ['Rohbau', 'Mauerwerk', 'Betonarbeiten', 'Fundamentbau', 'Schalungsarbeiten'],
        'logoUrl': '',
        'vatNumber': '',
        'verificationStatus': 'none',
      },
      {
        'id': '${_demoPrefix}3',
        'ownerId': '${_demoPrefix}3',
        'name': 'Elbe Elektrotechnik GmbH (Beispiel)',
        'description':
            'Elektroinstallation für Neubauten und Sanierungen. Zertifizierter Fachbetrieb für Stark- und Schwachstrom sowie Photovoltaik.',
        'website': 'www.elbe-elektro-demo.de',
        'email': 'auftraege@elbe-elektro-demo.de',
        'phone': '+49 40 5544332',
        'address': 'Elbchaussee 210',
        'city': 'Hamburg',
        'postalCode': '22605',
        'country': 'Deutschland',
        'employees': '11-50',
        'trade': 'Elektro',
        'services': ['Elektroinstallation', 'Photovoltaik', 'KNX/EIB', 'Gebäudeautomation'],
        'logoUrl': '',
        'vatNumber': 'DE998877665',
        'verificationStatus': 'verified',
      },
      {
        'id': '${_demoPrefix}4',
        'ownerId': '${_demoPrefix}4',
        'name': 'Hanseatische Dachbau KG (Beispiel)',
        'description':
            'Traditionsreicher Dachdeckerbetrieb mit Fokus auf Flach- und Steildach. Zertifizierter Verarbeiter von Bauder, Sika und Braas.',
        'website': 'www.hanse-dach-demo.de',
        'email': 'kontakt@hanse-dach-demo.de',
        'phone': '+49 40 7712340',
        'address': 'Borsteler Bogen 31',
        'city': 'Hamburg',
        'postalCode': '22453',
        'country': 'Deutschland',
        'employees': '11-50',
        'trade': 'Dach',
        'services': ['Flachdach', 'Steildach', 'Dachbegrünung', 'Dachdämmung', 'Dachklempnerei'],
        'logoUrl': '',
        'vatNumber': '',
        'verificationStatus': 'none',
      },
      {
        'id': '${_demoPrefix}5',
        'ownerId': '${_demoPrefix}5',
        'name': 'Nord-Tiefbau GmbH & Co. KG (Beispiel)',
        'description':
            'Tiefbau- und Straßenbauunternehmen für Kanalbau, Leitungstiefbau und Pflasterarbeiten im norddeutschen Raum. Eigener Maschinenpark.',
        'website': 'www.nord-tiefbau-demo.de',
        'email': 'info@nord-tiefbau-demo.de',
        'phone': '+49 40 3312980',
        'address': 'Moorburger Straße 88',
        'city': 'Hamburg',
        'postalCode': '21079',
        'country': 'Deutschland',
        'employees': '51-200',
        'trade': 'Tiefbau',
        'services': ['Kanalbau', 'Straßenbau', 'Leitungstiefbau', 'Erdbau', 'Pflasterarbeiten'],
        'logoUrl': '',
        'vatNumber': '',
        'verificationStatus': 'none',
      },
      {
        'id': '${_demoPrefix}6',
        'ownerId': '${_demoPrefix}6',
        'name': 'Alster Sanierung GmbH (Beispiel)',
        'description':
            'Vollsortimenter für Altbausanierung und energetische Modernisierung. BAFA-zertifizierter Energieberater, Erfahrung mit Denkmalschutzprojekten.',
        'website': 'www.alster-sanierung-demo.de',
        'email': 'sanierung@alster-sanierung-demo.de',
        'phone': '+49 40 9900118',
        'address': 'Uhlenhorster Weg 3',
        'city': 'Hamburg',
        'postalCode': '22085',
        'country': 'Deutschland',
        'employees': '11-50',
        'trade': 'Fassade',
        'services': ['Fassadensanierung', 'WDVS', 'Wärmedämmung', 'Putzarbeiten', 'Altbausanierung'],
        'logoUrl': '',
        'vatNumber': '',
        'verificationStatus': 'none',
      },
    ];
  }

  // ─────────────────────────────────────────────────────
  //  CAPACITY DATA (20 posts)
  // ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _capacities() {
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 30));
    final nextWeek = now.add(const Duration(days: 8));
    final in37 = now.add(const Duration(days: 37));
    final thisWeek = now.add(const Duration(days: 3));

    Timestamp created(int minutesAgo) =>
        Timestamp.fromDate(now.subtract(Duration(minutes: minutesAgo)));

    // ── VERFÜGBAR = offer, GESUCHT = need ────────────────
    return [
      // 1 ── Müller Trockenbau — VERFÜGBAR — LIVE (12 min ago)
      {
        'companyId': '${_demoPrefix}1',
        'companyName': 'Müller Trockenbau GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 1234567',
        'companyEmail': 'info@mueller-trockenbau-demo.de',
        'companyVerified': true,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'Trockenbauer für Altbausanierung — 4 Mann sofort frei',
        'description':
            'Unser 4-köpfiges Trockenbau-Team ist ab sofort für 3–4 Wochen verfügbar. Erfahren in Gipskarton, abgehängten Decken und Akustikwänden. Eigenes Werkzeug, saubere Arbeitsweise.',
        'trade': 'Trockenbau',
        'location': 'Hamburg-Altona',
        'workerCount': 4,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 87,
        'favoriteCount': 5,
        'interestCount': 2,
        'createdAt': created(12),
      },

      // 2 ── Müller Trockenbau — GESUCHT — LIVE (22 min ago)
      {
        'companyId': '${_demoPrefix}1',
        'companyName': 'Müller Trockenbau GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 1234567',
        'companyEmail': 'info@mueller-trockenbau-demo.de',
        'companyVerified': true,
        'type': 'need',
        'status': 'active',
        'availabilityType': 'thisWeek',
        'title': 'Elektroinstallateur für Neubau-Rohinstallation gesucht',
        'description':
            'Benötigen dringend Elektro-Subunternehmer für Rohinstallation in einem 12-Einheiten-Wohnneubau in Eimsbüttel. Beginn sofort, ca. 3 Wochen Laufzeit. Leitungswege freigeräumt.',
        'trade': 'Elektro',
        'location': 'Hamburg-Eimsbüttel',
        'workerCount': 2,
        'availableFrom': Timestamp.fromDate(thisWeek),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 43,
        'favoriteCount': 3,
        'interestCount': 1,
        'createdAt': created(22),
      },

      // 3 ── Müller Trockenbau — VERFÜGBAR — NEW (55 min ago)
      {
        'companyId': '${_demoPrefix}1',
        'companyName': 'Müller Trockenbau GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 1234567',
        'companyEmail': 'info@mueller-trockenbau-demo.de',
        'companyVerified': true,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'nextWeek',
        'title': 'Spachtelarbeiten & Malervorarbeiten — 2 Mann nächste Woche',
        'description':
            'Spezialisten für Glattstrich, Feinspachtel und Malervorarbeiten stehen ab nächster Woche bereit. Ideale Vorlage für Maler. Termintreu, sauber, eigenes Material auf Wunsch.',
        'trade': 'Trockenbau',
        'location': 'Hamburg-Winterhude',
        'workerCount': 2,
        'availableFrom': Timestamp.fromDate(nextWeek),
        'availableTo': Timestamp.fromDate(in37),
        'viewCount': 33,
        'favoriteCount': 2,
        'interestCount': 0,
        'createdAt': created(55),
      },

      // 4 ── Hamburg Rohbau — VERFÜGBAR — NEW (48 min ago)
      {
        'companyId': '${_demoPrefix}2',
        'companyName': 'Hamburg Rohbau AG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 9876543',
        'companyEmail': 'projekte@hamburg-rohbau-demo.de',
        'companyVerified': false,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'thisWeek',
        'title': 'Rohbaukolonne 8 Facharbeiter — ab Dienstag einsetzbar',
        'description':
            'Komplette Rohbaukolonne mit Polier steht ab Dienstag bereit. Mauerwerk, Schalungs- und Betonierarbeiten. Eigenes Werkzeug und Kleingeräte inklusive. Leistungsstarkes Team.',
        'trade': 'Rohbau',
        'location': 'Hamburg-Hammerbrook',
        'workerCount': 8,
        'availableFrom': Timestamp.fromDate(thisWeek),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 134,
        'favoriteCount': 9,
        'interestCount': 4,
        'createdAt': created(48),
      },

      // 5 ── Hamburg Rohbau — GESUCHT — LIVE (8 min ago)
      {
        'companyId': '${_demoPrefix}2',
        'companyName': 'Hamburg Rohbau AG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 9876543',
        'companyEmail': 'projekte@hamburg-rohbau-demo.de',
        'companyVerified': false,
        'type': 'need',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'Betonpumpe + Bediener für Deckenplatte — sofort',
        'description':
            'Betoniertermin am Wochenende: Betonpumpe inkl. Bediener gesucht. Ca. 80 m³, Zufahrt für 32m-Pumpe vorhanden. Raum Hamburg-Mitte. Vergütung nach Stundenabrechnung.',
        'trade': 'Beton',
        'location': 'Hamburg-Mitte',
        'workerCount': 1,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(thisWeek),
        'viewCount': 56,
        'favoriteCount': 4,
        'interestCount': 2,
        'createdAt': created(8),
      },

      // 6 ── Hamburg Rohbau — VERFÜGBAR — 3h ago
      {
        'companyId': '${_demoPrefix}2',
        'companyName': 'Hamburg Rohbau AG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 9876543',
        'companyEmail': 'projekte@hamburg-rohbau-demo.de',
        'companyVerified': false,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'nextWeek',
        'title': '2 Maurer mit Kalksandstein-Erfahrung — nächste Woche frei',
        'description':
            'Zwei erfahrene Maurer (Kalksandstein, Poroton) stehen ab nächster Woche für ca. 2 Wochen zur Verfügung. Eigenes Fahrzeug, verlässliches Team, flexible Einsatzzeiten.',
        'trade': 'Rohbau',
        'location': 'Hamburg-Barmbek',
        'workerCount': 2,
        'availableFrom': Timestamp.fromDate(nextWeek),
        'availableTo': Timestamp.fromDate(in37),
        'viewCount': 29,
        'favoriteCount': 2,
        'interestCount': 0,
        'createdAt': created(180),
      },

      // 7 ── Elbe Elektro — VERFÜGBAR — LIVE (18 min ago)
      {
        'companyId': '${_demoPrefix}3',
        'companyName': 'Elbe Elektrotechnik GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 5544332',
        'companyEmail': 'auftraege@elbe-elektro-demo.de',
        'companyVerified': true,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'Elektro-Team 3 Mann — Neubau und Sanierung — sofort',
        'description':
            'Eingespieltes 3-Mann-Team für Elektroinstallation sofort verfügbar. Stark- und Schwachstrom, KNX/EIB-Erfahrung vorhanden. Komplett ausgerüstet, eigenes Fahrzeug.',
        'trade': 'Elektro',
        'location': 'Hamburg-Ottensen',
        'workerCount': 3,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 112,
        'favoriteCount': 7,
        'interestCount': 3,
        'createdAt': created(18),
      },

      // 8 ── Elbe Elektro — GESUCHT — 4h ago
      {
        'companyId': '${_demoPrefix}3',
        'companyName': 'Elbe Elektrotechnik GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 5544332',
        'companyEmail': 'auftraege@elbe-elektro-demo.de',
        'companyVerified': true,
        'type': 'need',
        'status': 'active',
        'availabilityType': 'thisWeek',
        'title': 'Sanitärinstallateur für 2 Badsanierungen in Blankenese',
        'description':
            'Für Sanierungsprojekt in Blankenese (2 Bäder, EFH) suchen wir Sanitär-Subunternehmer. Ca. 5–6 Tage Arbeitsumfang. Badeinrichtung durch Bauherrn gestellt, Zu-/Ableitungen neu.',
        'trade': 'Sanitär & Heizung',
        'location': 'Hamburg-Blankenese',
        'workerCount': 2,
        'availableFrom': Timestamp.fromDate(thisWeek),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 38,
        'favoriteCount': 2,
        'interestCount': 1,
        'createdAt': created(240),
      },

      // 9 ── Elbe Elektro — VERFÜGBAR — NEW (70 min ago)
      {
        'companyId': '${_demoPrefix}3',
        'companyName': 'Elbe Elektrotechnik GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 5544332',
        'companyEmail': 'auftraege@elbe-elektro-demo.de',
        'companyVerified': true,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'thisWeek',
        'title': 'Zertifizierter PV-Monteur — diese Woche verfügbar',
        'description':
            'PV-Monteur für Dachanlage und Wechselrichterinstallation verfügbar. Erfahrung mit Fronius, SMA und Huawei. DC- und AC-seitige Installation. Gerüst durch Auftraggeber.',
        'trade': 'Elektro',
        'location': 'Hamburg-Wandsbek',
        'workerCount': 1,
        'availableFrom': Timestamp.fromDate(thisWeek),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 67,
        'favoriteCount': 6,
        'interestCount': 2,
        'createdAt': created(70),
      },

      // 10 ── Elbe Elektro — GESUCHT — 5h ago
      {
        'companyId': '${_demoPrefix}3',
        'companyName': 'Elbe Elektrotechnik GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 5544332',
        'companyEmail': 'auftraege@elbe-elektro-demo.de',
        'companyVerified': true,
        'type': 'need',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'Kabelzug-Helfer für HafenCity-Großprojekt — sofort',
        'description':
            'Für Gewerbe-Neubau in der HafenCity suchen wir 5 Helfer (Kabelzug, Verlegung, Rangieren). Keine Fachkenntnisse erforderlich. Stundenweise Abrechnung, faire Vergütung.',
        'trade': 'Elektro',
        'location': 'Hamburg-HafenCity',
        'workerCount': 5,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 76,
        'favoriteCount': 4,
        'interestCount': 2,
        'createdAt': created(300),
      },

      // 11 ── Hanse Dachbau — VERFÜGBAR — LIVE (5 min ago)
      {
        'companyId': '${_demoPrefix}4',
        'companyName': 'Hanseatische Dachbau KG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 7712340',
        'companyEmail': 'kontakt@hanse-dach-demo.de',
        'companyVerified': false,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'Dachdecker-Kolonne 5 Mann — Flachdach & Steildach',
        'description':
            'Erfahrene Dachdecker-Kolonne mit eigenem Gerüst für Flach- und Steildacharbeiten kurzfristig verfügbar. Zert. Verarbeiter Bauder, Sika, Braas. Eigene Fahrzeuge.',
        'trade': 'Dach',
        'location': 'Hamburg-Harburg',
        'workerCount': 5,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 93,
        'favoriteCount': 8,
        'interestCount': 3,
        'createdAt': created(5),
      },

      // 12 ── Hanse Dachbau — GESUCHT — 6h ago
      {
        'companyId': '${_demoPrefix}4',
        'companyName': 'Hanseatische Dachbau KG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 7712340',
        'companyEmail': 'kontakt@hanse-dach-demo.de',
        'companyVerified': false,
        'type': 'need',
        'status': 'active',
        'availabilityType': 'nextWeek',
        'title': 'Stahlbauer für Carport-Konstruktion in Rahlstedt gesucht',
        'description':
            'Wohnprojekt Rahlstedt: Stahlbauer für Carport-Stahlkonstruktion gesucht. Ca. 3 Tage Montage, Pläne vorhanden, Material durch uns. Beginn nächste Woche gewünscht.',
        'trade': 'Stahl',
        'location': 'Hamburg-Rahlstedt',
        'workerCount': 3,
        'availableFrom': Timestamp.fromDate(nextWeek),
        'availableTo': Timestamp.fromDate(in37),
        'viewCount': 21,
        'favoriteCount': 1,
        'interestCount': 0,
        'createdAt': created(360),
      },

      // 13 ── Hanse Dachbau — VERFÜGBAR — 8h ago
      {
        'companyId': '${_demoPrefix}4',
        'companyName': 'Hanseatische Dachbau KG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 7712340',
        'companyEmail': 'kontakt@hanse-dach-demo.de',
        'companyVerified': false,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'thisWeek',
        'title': 'Fassadenputz-Team 3 Mann — Neubau Außenfassade',
        'description':
            'Putztrupp (3 Mann) für Außenputz und Fassadengestaltung verfügbar. WDVS-Erfahrung, Maschinenputz und Handputz. Gerüst durch Auftraggeber. Terminzuverlässig.',
        'trade': 'Fassade',
        'location': 'Hamburg-Poppenbüttel',
        'workerCount': 3,
        'availableFrom': Timestamp.fromDate(thisWeek),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 45,
        'favoriteCount': 3,
        'interestCount': 1,
        'createdAt': created(480),
      },

      // 14 ── Nord-Tiefbau — VERFÜGBAR — LIVE (25 min ago)
      {
        'companyId': '${_demoPrefix}5',
        'companyName': 'Nord-Tiefbau GmbH & Co. KG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 3312980',
        'companyEmail': 'info@nord-tiefbau-demo.de',
        'companyVerified': false,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'Tiefbaukolonne 6 Mann + 20t-Bagger — sofort verfügbar',
        'description':
            'Tiefbaukolonne inkl. 20t-Kettenbagger und Raupenfahrzeug für Erdarbeiten und Kanalbau. 6 Fachkräfte + Maschinenführer, eigene Baustellenbeleuchtung, kurzfristig einsetzbar.',
        'trade': 'Tiefbau',
        'location': 'Hamburg-Bergedorf',
        'workerCount': 6,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 142,
        'favoriteCount': 11,
        'interestCount': 5,
        'createdAt': created(25),
      },

      // 15 ── Nord-Tiefbau — GESUCHT — 12h ago
      {
        'companyId': '${_demoPrefix}5',
        'companyName': 'Nord-Tiefbau GmbH & Co. KG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 3312980',
        'companyEmail': 'info@nord-tiefbau-demo.de',
        'companyVerified': false,
        'type': 'need',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'Bitumen-Lieferant für Kanalsanierung — 40t Bedarf sofort',
        'description':
            'Laufende Kanalsanierung: ca. 40 Tonnen Heißbitumen kurzfristig benötigt. Lieferung an 3 Baustellen im Hamburger Hafen. Konditionen auf Anfrage. Sofortauftrag.',
        'trade': 'Lieferant',
        'location': 'Hamburg-Hafen',
        'workerCount': 1,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(thisWeek),
        'viewCount': 34,
        'favoriteCount': 2,
        'interestCount': 1,
        'createdAt': created(720),
      },

      // 16 ── Nord-Tiefbau — VERFÜGBAR — 1 day ago
      {
        'companyId': '${_demoPrefix}5',
        'companyName': 'Nord-Tiefbau GmbH & Co. KG (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 3312980',
        'companyEmail': 'info@nord-tiefbau-demo.de',
        'companyVerified': false,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'nextWeek',
        'title': 'Straßenbaukolonne 4 Mann — Pflaster & Asphalt',
        'description':
            'Straßenbaukolonne für Pflasterarbeiten und Asphaltierung ab nächster Woche verfügbar. Öffentliche Ausschreibungen bekannt. Eigene Kompressoren und Verdichtungsgerät.',
        'trade': 'Tiefbau',
        'location': 'Hamburg-Neustadt',
        'workerCount': 4,
        'availableFrom': Timestamp.fromDate(nextWeek),
        'availableTo': Timestamp.fromDate(in37),
        'viewCount': 18,
        'favoriteCount': 1,
        'interestCount': 0,
        'createdAt': created(1440),
      },

      // 17 ── Alster Sanierung — VERFÜGBAR — 2 days ago
      {
        'companyId': '${_demoPrefix}6',
        'companyName': 'Alster Sanierung GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 9900118',
        'companyEmail': 'sanierung@alster-sanierung-demo.de',
        'companyVerified': false,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'thisWeek',
        'title': 'Komplett-Sanierungsteam 10 Mann — Altbau & Denkmalschutz',
        'description':
            'Sanierungsteam (10 Personen, Mehrgewerke) für denkmalgerechte Altbausanierung. Eigene BAFA-Förderberatung, Erfahrung mit Denkmalschutzbehörde Hamburg. Referenzen vorhanden.',
        'trade': 'Fassade',
        'location': 'Hamburg-Eppendorf',
        'workerCount': 10,
        'availableFrom': Timestamp.fromDate(thisWeek),
        'availableTo': Timestamp.fromDate(in37),
        'viewCount': 78,
        'favoriteCount': 6,
        'interestCount': 2,
        'createdAt': created(2880),
      },

      // 18 ── Alster Sanierung — GESUCHT — 3 days ago
      {
        'companyId': '${_demoPrefix}6',
        'companyName': 'Alster Sanierung GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 9900118',
        'companyEmail': 'sanierung@alster-sanierung-demo.de',
        'companyVerified': false,
        'type': 'need',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'HVAC-Monteur für Wohnraumlüftung — DG-Ausbau Eppendorf',
        'description':
            'DG-Ausbau Eppendorf: HVAC-Monteur für Planung und Montage einer Wohnraumlüftung (ca. 280 m²) gesucht. Pläne vorhanden. Beginn sofort möglich, ca. 1 Woche Einsatz.',
        'trade': 'HVAC',
        'location': 'Hamburg-Eppendorf',
        'workerCount': 2,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 52,
        'favoriteCount': 4,
        'interestCount': 1,
        'createdAt': created(4320),
      },

      // 19 ── Alster Sanierung — VERFÜGBAR — 4 days ago
      {
        'companyId': '${_demoPrefix}6',
        'companyName': 'Alster Sanierung GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 9900118',
        'companyEmail': 'sanierung@alster-sanierung-demo.de',
        'companyVerified': false,
        'type': 'offer',
        'status': 'active',
        'availabilityType': 'now',
        'title': 'WDVS-Team 2 Mann — EPS & Mineralwolle — sofort frei',
        'description':
            'Erfahrenes WDVS-Team für Außendämmung und Fassadengestaltung sofort verfügbar. EPS- und Mineralwolle-Systeme (Baumit, Caparol). Eigenes Werkzeug, faire Stundenabrechnung.',
        'trade': 'Fassade',
        'location': 'Hamburg-Altona',
        'workerCount': 2,
        'availableFrom': Timestamp.fromDate(now),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 61,
        'favoriteCount': 5,
        'interestCount': 2,
        'createdAt': created(5760),
      },

      // 20 ── Alster Sanierung — GESUCHT — 5 days ago
      {
        'companyId': '${_demoPrefix}6',
        'companyName': 'Alster Sanierung GmbH (Beispiel)',
        'companyCity': 'Hamburg',
        'companyPhone': '+49 40 9900118',
        'companyEmail': 'sanierung@alster-sanierung-demo.de',
        'companyVerified': false,
        'type': 'need',
        'status': 'active',
        'availabilityType': 'thisWeek',
        'title': 'Sanitär-Subunternehmer für 6 Badezimmer gesucht — Eppendorf',
        'description':
            'Umfangreiche Kernsanierung in Eppendorf: 6 Badezimmer (Fliesen durch andere Gewerke). Gesucht: Sanitär-Subunternehmer für Zu-/Ableitungen und vollständige Neuinstallation.',
        'trade': 'Sanitär & Heizung',
        'location': 'Hamburg-Eppendorf',
        'workerCount': 3,
        'availableFrom': Timestamp.fromDate(thisWeek),
        'availableTo': Timestamp.fromDate(soon),
        'viewCount': 44,
        'favoriteCount': 3,
        'interestCount': 1,
        'createdAt': created(7200),
      },
    ];
  }
}
