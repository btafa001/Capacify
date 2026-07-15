import 'package:cloud_firestore/cloud_firestore.dart';
import '../localization/app_localizations.dart';

class CompanyModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  // Self-declared qualifications, memberships & insurance (e.g. "Meisterbetrieb,
  // Innung SHK Hamburg, Betriebshaftpflicht") — a trust signal on the profile.
  final String certifications;
  final String website;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String postalCode;
  final String country;
  final String employees;
  final List<String> trades;
  final List<String> services;
  final String logoUrl;
  final String vatNumber;
  final String verificationStatus;
  // Set by the verifyMyCompany Cloud Function: whether the VAT passed the EU
  // VIES check, and the name VIES has on file. Used by the admin verification
  // card to give the founder a confident Freigabe. Never auto-verifies.
  final bool vatValid;
  final String vatVerifiedName;
  final int ratingSum;
  final int ratingCount;
  // Responsiveness signal — running sum+count of how long this company took to
  // answer contact requests (stamped on accept/decline). Surfaces as "Antwortet
  // meist in ~Xh" once there are enough samples; also a CapacityOS data point.
  final int responseCount;
  final int responseSumMs;
  // Completed collaborations (both parties confirmed "we worked together") and
  // how many of those were with a repeat partner. Incremented server-side by a
  // Cloud Function so neither side can inflate its own count. Trust + CapacityOS.
  final int completedCollaborations;
  final int repeatCollaborations;
  final bool contentFlagged;
  // Why contentFlagged got set server-side (enforceCapacityModeration /
  // enforceCompanyIntegrity in functions/index.js) — 'moderation' (blocked
  // word / leaked contact info) or 'impersonation' (name suspiciously close
  // to an already-verified company). flagDetail carries the matched verified
  // company's name for the impersonation case. Admin-display only — never
  // written by the client, and clearing contentFlagged (approve) is all the
  // moderation queue needs regardless of which reason is shown.
  final String flagReason;
  final String flagDetail;
  // Admin-only "pause" — a deliberate moderation consequence (distinct from
  // contentFlagged, which is auto-detected). While true: the company can't
  // publish new posts (firestore.rules) and its existing posts are hidden
  // from the public feed (see CapacityModel.posterSuspended). Never
  // self-settable — excluded from toFirestoreForUpdate, pinned admin-only in
  // firestore.rules. suspensionReason is shown to the company itself so the
  // consequence isn't a silent black box.
  final bool suspended;
  final String suspensionReason;
  // Opt-in (default false, GDPR) for the retention emails — match alerts +
  // weekly digest. Managed via CompanyService.setEmailOptIn, never touched by
  // the profile-save path, so it can't be clobbered by a stale model.
  final bool emailOptIn;
  final DateTime? createdAt;
  // Onboarding provenance — 'self' for companies that registered themselves
  // (the default, and what every pre-existing doc reads as), 'admin' for
  // accounts created during admin-assisted phone onboarding. invitedAt is
  // stamped only when an admin sends the set-password invite, so admins can
  // tell "created but not yet invited" from "invited, waiting on the company."
  final String onboardingSource; // 'self' | 'admin'
  final String onboardingAdminUid;
  final DateTime? invitedAt;
  // When the company name was last changed — drives the rename cooldown policy.
  final DateTime? lastNameChangeAt;
  // Last time the company was active (stamped on login) — a trust/liveness
  // signal ("Zuletzt aktiv heute") on company profiles.
  final DateTime? lastActiveAt;
  // Referral attribution — the inviting company's id, captured from a
  // ?ref={companyId} link at registration (see auth_service.dart). Stamped
  // once at creation, never editable. '' for the overwhelming majority of
  // companies (organic signups). Powers the referrer's "Empfehlungen: Nx"
  // count in Settings — see companyService.countReferrals.
  final String referredBy;

  bool get isVerified => verificationStatus == 'verified';
  double get avgRating => ratingCount > 0 ? ratingSum / ratingCount : 0.0;

  /// Average response time, in hours (rounded up, min 1) — only meaningful once
  /// there are enough samples. Null until then, so the UI can hide the signal
  /// rather than show a noisy one-sample average.
  int? get avgResponseHours {
    if (responseCount < 3) return null;
    final avgMs = responseSumMs / responseCount;
    final hours = (avgMs / (1000 * 60 * 60)).ceil();
    return hours < 1 ? 1 : hours;
  }

  // Profile completeness is based on the fields that make a listing genuinely
  // useful to others — not name/employees/city, which are already required
  // or defaulted at registration. trades IS included since registration no
  // longer collects it (deferred to the profile page, like everything else
  // here).
  static double calculateCompleteness({
    required String description,
    required String website, // kept for call-site compatibility; no longer scored
    required String phone,
    required String address,
    required List<String> trades,
  }) {
    // Website is OPTIONAL — not part of completeness. A company can reach 100%
    // without one.
    final checks = [
      description.trim().isNotEmpty,
      phone.trim().isNotEmpty,
      address.trim().isNotEmpty,
      trades.isNotEmpty,
    ];
    return checks.where((met) => met).length / checks.length;
  }

  double get profileCompleteness => calculateCompleteness(
        description: description,
        website: website,
        phone: phone,
        address: address,
        trades: trades,
      );

  bool get isProfileComplete => profileCompleteness >= 1.0;

  /// Which of the fields that gate isProfileComplete are still missing, as a
  /// display-ready comma list — used to tell a company EXACTLY what to add
  /// instead of a generic "complete your profile" notice (dashboard_screen.dart's
  /// post-gate dialog, interest_modal.dart's contact-gate notice). Still
  /// relevant even now that the profile form requires these fields going
  /// forward — a company saved under the old, more lenient validators may
  /// already have one empty on file.
  String missingCompletenessFieldsLabel(AppLocalizations l) {
    final missing = <String>[];
    if (description.trim().isEmpty) missing.add(l.missingFieldDescription);
    if (phone.trim().isEmpty) missing.add(l.missingFieldPhoneCompany);
    if (address.trim().isEmpty) missing.add(l.missingFieldAddress);
    if (trades.isEmpty) missing.add(l.missingFieldTrades);
    return missing.join(', ');
  }

  CompanyModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    this.certifications = '',
    required this.website,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.employees,
    required this.trades,
    required this.services,
    required this.logoUrl,
    this.vatNumber = '',
    this.verificationStatus = 'none',
    this.vatValid = false,
    this.vatVerifiedName = '',
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.responseCount = 0,
    this.responseSumMs = 0,
    this.completedCollaborations = 0,
    this.repeatCollaborations = 0,
    this.contentFlagged = false,
    this.flagReason = '',
    this.flagDetail = '',
    this.suspended = false,
    this.suspensionReason = '',
    this.emailOptIn = false,
    this.createdAt,
    this.lastActiveAt,
    this.referredBy = '',
    this.onboardingSource = 'self',
    this.onboardingAdminUid = '',
    this.invitedAt,
    this.lastNameChangeAt,
  });

  /// A minimal, partial instance built from just the identity snapshot a
  /// visible/discreet capacity post carries (id/name/logoUrl) — enough to
  /// open showCompanyDetailDialog before the real doc has loaded.
  /// CompanyDetailScreen re-fetches the live doc via companyByIdProvider and
  /// falls back to whatever it was handed (`companyAsync.value ?? company`),
  /// so this self-corrects the instant the live stream resolves; every other
  /// field here is a safe, empty placeholder, never actually displayed for
  /// more than a frame.
  factory CompanyModel.shellFor({
    required String id,
    required String name,
    String logoUrl = '',
  }) {
    return CompanyModel(
      id: id,
      ownerId: id,
      name: name,
      description: '',
      website: '',
      email: '',
      phone: '',
      address: '',
      city: '',
      postalCode: '',
      country: '',
      employees: '',
      trades: const [],
      services: const [],
      logoUrl: logoUrl,
    );
  }

  CompanyModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? certifications,
    String? website,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? employees,
    List<String>? trades,
    List<String>? services,
    String? logoUrl,
    String? vatNumber,
    String? verificationStatus,
    bool? vatValid,
    String? vatVerifiedName,
    int? ratingSum,
    int? ratingCount,
    int? responseCount,
    int? responseSumMs,
    int? completedCollaborations,
    int? repeatCollaborations,
    bool? contentFlagged,
    String? flagReason,
    String? flagDetail,
    bool? suspended,
    String? suspensionReason,
    bool? emailOptIn,
    DateTime? createdAt,
    String? onboardingSource,
    String? onboardingAdminUid,
    DateTime? invitedAt,
    DateTime? lastNameChangeAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      certifications: certifications ?? this.certifications,
      website: website ?? this.website,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      employees: employees ?? this.employees,
      trades: trades ?? this.trades,
      services: services ?? this.services,
      logoUrl: logoUrl ?? this.logoUrl,
      vatNumber: vatNumber ?? this.vatNumber,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      vatValid: vatValid ?? this.vatValid,
      vatVerifiedName: vatVerifiedName ?? this.vatVerifiedName,
      ratingSum: ratingSum ?? this.ratingSum,
      ratingCount: ratingCount ?? this.ratingCount,
      responseCount: responseCount ?? this.responseCount,
      responseSumMs: responseSumMs ?? this.responseSumMs,
      completedCollaborations: completedCollaborations ?? this.completedCollaborations,
      repeatCollaborations: repeatCollaborations ?? this.repeatCollaborations,
      contentFlagged: contentFlagged ?? this.contentFlagged,
      flagReason: flagReason ?? this.flagReason,
      flagDetail: flagDetail ?? this.flagDetail,
      suspended: suspended ?? this.suspended,
      suspensionReason: suspensionReason ?? this.suspensionReason,
      emailOptIn: emailOptIn ?? this.emailOptIn,
      createdAt: createdAt ?? this.createdAt,
      onboardingSource: onboardingSource ?? this.onboardingSource,
      onboardingAdminUid: onboardingAdminUid ?? this.onboardingAdminUid,
      invitedAt: invitedAt ?? this.invitedAt,
      lastNameChangeAt: lastNameChangeAt ?? this.lastNameChangeAt,
    );
  }

  // Convert Firestore document to CompanyModel
  factory CompanyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Backward-compat: older documents stored a single 'trade' string;
    // current documents store a 'trades' list (up to 2).
    final tradesData = data['trades'];
    final List<String> trades = tradesData is List
        ? List<String>.from(tradesData)
        : (data['trade'] is String && (data['trade'] as String).isNotEmpty
            ? [data['trade'] as String]
            : <String>[]);
    return CompanyModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      certifications: data['certifications'] ?? '',
      website: data['website'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      postalCode: data['postalCode'] ?? '',
      country: data['country'] ?? 'Deutschland',
      employees: data['employees'] ?? '',
      trades: trades,
      services: List<String>.from(data['services'] ?? []),
      logoUrl: data['logoUrl'] ?? '',
      vatNumber: data['vatNumber'] ?? '',
      verificationStatus: data['verificationStatus'] ?? 'none',
      vatValid: data['vatValid'] as bool? ?? false,
      vatVerifiedName: data['vatVerifiedName'] as String? ?? '',
      ratingSum: data['ratingSum'] ?? 0,
      ratingCount: data['ratingCount'] ?? 0,
      responseCount: data['responseCount'] ?? 0,
      responseSumMs: (data['responseSumMs'] as num?)?.toInt() ?? 0,
      completedCollaborations: data['completedCollaborations'] ?? 0,
      repeatCollaborations: data['repeatCollaborations'] ?? 0,
      contentFlagged: data['contentFlagged'] as bool? ?? false,
      flagReason: data['flagReason'] as String? ?? '',
      flagDetail: data['flagDetail'] as String? ?? '',
      suspended: data['suspended'] as bool? ?? false,
      suspensionReason: data['suspensionReason'] as String? ?? '',
      emailOptIn: data['emailOptIn'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
      referredBy: data['referredBy'] as String? ?? '',
      // Pre-existing docs have no onboardingSource — default to 'self', the
      // same backward-compat pattern used for legacy 'trade' above.
      onboardingSource: data['onboardingSource'] as String? ?? 'self',
      onboardingAdminUid: data['onboardingAdminUid'] as String? ?? '',
      invitedAt: (data['invitedAt'] as Timestamp?)?.toDate(),
      lastNameChangeAt: (data['lastNameChangeAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert CompanyModel to Map for Firestore — used only on initial creation.
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'certifications': certifications,
      'website': website,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'employees': employees,
      'trades': trades,
      'services': services,
      'logoUrl': logoUrl,
      'vatNumber': vatNumber,
      'verificationStatus': verificationStatus,
      'ratingSum': ratingSum,
      'ratingCount': ratingCount,
      'contentFlagged': contentFlagged,
      'emailOptIn': emailOptIn,
      'createdAt': FieldValue.serverTimestamp(),
      'referredBy': referredBy,
      'onboardingSource': onboardingSource,
      'onboardingAdminUid': onboardingAdminUid,
      // invitedAt is intentionally NOT written here — it stays null until an
      // admin explicitly sends the invite (markInvited), never at creation.
    };
  }

  /// For editing an existing company's profile fields. Deliberately excludes
  /// ratingSum/ratingCount/createdAt (managed by submitRating()) — Firestore's
  /// update() only touches keys present here, so omitting them leaves the
  /// existing values untouched. contentFlagged IS included since it's derived
  /// from the description text and must be recomputed on save. vatNumber and
  /// verificationStatus ARE included since verification can now be requested
  /// from the profile page — callers must compute verificationStatus
  /// carefully so an already-'verified' company is never auto-downgraded.
  Map<String, dynamic> toFirestoreForUpdate() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'certifications': certifications,
      'website': website,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'employees': employees,
      'trades': trades,
      'services': services,
      'logoUrl': logoUrl,
      'vatNumber': vatNumber,
      'verificationStatus': verificationStatus,
      'contentFlagged': contentFlagged,
      // Preserve/refresh the rename-cooldown stamp (only ever set on a rename).
      if (lastNameChangeAt != null) 'lastNameChangeAt': Timestamp.fromDate(lastNameChangeAt!),
    };
  }
}