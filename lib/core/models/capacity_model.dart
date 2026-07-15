import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';

enum CapacityType { offer, need }

enum CapacityStatus {
  active,
  inProgress,
  closed,
  cancelled,
}

enum AvailabilityType { now, thisWeek, nextWeek, custom }

// Chosen once at creation, immutable afterward (excluded from
// toFirestoreForUpdate — see there). `visible`/`discreet` are functionally
// identical (name + logo + verified badge shown, contact still gated) —
// discreet is framing/copy only, not a technical restriction. `anonymous` is
// today's original behavior: zero identity on the post, and the only mode
// that still requires the poster's deliberate Accept before a contact
// request grants (see ContactRequestService.requestContact).
enum CapacityVisibilityMode { visible, discreet, anonymous }

// PUBLIC post. For `anonymous` posts (still the default for any pre-existing
// document with no visibilityMode field — see fromFirestore), this carries NO
// poster identity — no companyId/name/city/phone/email/verified; identity
// lives only in the locked capacityOwners/{id} sidecar (see
// CapacityOwnerModel), released by Firestore rules to the owner, an admin, or
// a granted contact requester. For `visible`/`discreet` posts, posterCompanyId/
// posterCompanyName/posterLogoUrl ARE present directly on this doc (a
// snapshot, not a live join — same pattern as posterVerified/posterRatingSum
// below — since companies/{id} is already fully public, so this only
// determines whether identity shows up on the anonymized feed itself).
// Contact details (phone/email) stay in the locked sidecar regardless of
// mode — visibilityMode only ever controls whether IDENTITY is exposed here,
// never contact info. The Firestore auto-id is the only post identifier and
// links nothing across a firm's posts.
class CapacityModel {
  final String id;
  final CapacityType type;
  final CapacityStatus status;
  final AvailabilityType availabilityType;
  final String title;
  final String description;
  final String trade;
  final String location;
  final int workerCount;
  final DateTime availableFrom;
  final DateTime availableTo;
  final int viewCount;
  final int favoriteCount;
  final int interestCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // When the poster last re-confirmed "still available" (one-tap). Drives the
  // strongest freshness signal ("heute bestätigt") and feeds CapacityOS.
  final DateTime? availabilityConfirmedAt;
  final DateTime? closedAt;
  final DateTime? cancelledAt;
  final int? dealNumber;
  final bool contentFlagged;
  // Non-identifying trust signals snapshotted from the poster's company at
  // post time. Aggregate (many firms share them) — NOT a stable per-company
  // identifier, so they build confidence without revealing who posted.
  final bool posterVerified;
  final int posterRatingSum;
  final int posterRatingCount;
  // Snapshot of the poster's CompanyModel.suspended, batch-flipped onto every
  // one of their posts by AdminService.suspendCompany/unsuspendCompany (same
  // snapshot-not-live-join pattern as posterVerified above). Hides the post
  // from the public feed — see CapacityService.getCapacities — without
  // requiring a feed-time join against the company doc.
  final bool posterSuspended;
  // Poster's responsiveness (see CompanyModel.avgResponseHours), synced onto
  // every one of their posts so it's visible on the anonymized CARD itself —
  // the actual decision point for "who do I contact," which is before their
  // profile (and thus their responsiveness) would otherwise be viewable at
  // all for an anonymized post. Null until they have >=3 samples (same
  // no-noisy-single-sample rule as the company-level getter).
  final int? posterAvgResponseHours;
  // CapacityOS readiness — additive, all optional, cheap to capture now vs.
  // expensive to backfill onto months of historical posts later.
  // Derived automatically from `location` via kHamburgDistrictCoordinates —
  // never user-entered — so it's always consistent with the district string,
  // or absent if that string doesn't match a known district (e.g. edited to
  // free text away from the original dropdown value).
  final GeoPoint? districtCoordinates;
  // Self-reported day-rate band (see kDayRateBands) — '' means undisclosed.
  final String dayRateBand;
  // Free-text specifics below the fixed trade granularity (e.g. "Führerschein
  // Klasse B, Hubarbeitsbühne-Schein") — optional.
  final String skillDetails;
  // See the enum doc above. null-valued identity fields below ⇒ anonymous.
  final CapacityVisibilityMode visibilityMode;
  final String? posterCompanyId;
  final String? posterCompanyName;
  final String? posterLogoUrl;

  double get posterRating =>
      posterRatingCount > 0 ? posterRatingSum / posterRatingCount : 0.0;

  /// Looks up the approximate centroid for a known Hamburg district string —
  /// null if [location] doesn't exactly match one (see kHamburgDistrictCoordinates).
  static GeoPoint? coordinatesForLocation(String location) {
    final coords = kHamburgDistrictCoordinates[location];
    if (coords == null) return null;
    return GeoPoint(coords.$1, coords.$2);
  }

  CapacityModel({
    required this.id,
    required this.type,
    required this.status,
    required this.availabilityType,
    required this.title,
    required this.description,
    required this.trade,
    required this.location,
    required this.workerCount,
    required this.availableFrom,
    required this.availableTo,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.interestCount = 0,
    this.createdAt,
    this.updatedAt,
    this.availabilityConfirmedAt,
    this.closedAt,
    this.cancelledAt,
    this.dealNumber,
    this.contentFlagged = false,
    this.posterVerified = false,
    this.posterRatingSum = 0,
    this.posterRatingCount = 0,
    this.posterSuspended = false,
    this.posterAvgResponseHours,
    this.districtCoordinates,
    this.dayRateBand = '',
    this.skillDetails = '',
    this.visibilityMode = CapacityVisibilityMode.visible,
    this.posterCompanyId,
    this.posterCompanyName,
    this.posterLogoUrl,
  });

  // ─── fromFirestore ───

  factory CapacityModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    CapacityType type = CapacityType.offer;
    if (data['type'] == 'need') type = CapacityType.need;

    CapacityStatus status = _statusFromString(
      data['status'] ?? 'active',
    );

    AvailabilityType availabilityType =
        AvailabilityType.thisWeek;
    if (data['availabilityType'] == 'now') {
      availabilityType = AvailabilityType.now;
    } else if (data['availabilityType'] == 'nextWeek') {
      availabilityType = AvailabilityType.nextWeek;
    } else if (data['availabilityType'] == 'custom') {
      availabilityType = AvailabilityType.custom;
    }

    return CapacityModel(
      id: doc.id,
      type: type,
      status: status,
      availabilityType: availabilityType,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      trade: data['trade'] ?? '',
      location: data['location'] ?? '',
      workerCount: data['workerCount'] ?? 1,
      availableFrom:
          (data['availableFrom'] as Timestamp).toDate(),
      availableTo:
          (data['availableTo'] as Timestamp).toDate(),
      viewCount: data['viewCount'] ?? 0,
      favoriteCount: data['favoriteCount'] ?? 0,
      interestCount: data['interestCount'] ?? 0,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate(),
      availabilityConfirmedAt:
          (data['availabilityConfirmedAt'] as Timestamp?)?.toDate(),
      closedAt:
          (data['closedAt'] as Timestamp?)?.toDate(),
      cancelledAt:
          (data['cancelledAt'] as Timestamp?)?.toDate(),
      dealNumber: data['dealNumber'] as int?,
      contentFlagged: data['contentFlagged'] as bool? ?? false,
      posterVerified: data['posterVerified'] as bool? ?? false,
      posterRatingSum: data['posterRatingSum'] ?? 0,
      posterRatingCount: data['posterRatingCount'] ?? 0,
      posterSuspended: data['posterSuspended'] as bool? ?? false,
      posterAvgResponseHours: data['posterAvgResponseHours'] as int?,
      districtCoordinates: data['districtCoordinates'] as GeoPoint?,
      dayRateBand: data['dayRateBand'] as String? ?? '',
      skillDetails: data['skillDetails'] as String? ?? '',
      visibilityMode: _visibilityModeFromString(data['visibilityMode'] as String?),
      posterCompanyId: data['posterCompanyId'] as String?,
      posterCompanyName: data['posterCompanyName'] as String?,
      posterLogoUrl: data['posterLogoUrl'] as String?,
    );
  }

  // ─── toFirestore ───

  Map<String, dynamic> toFirestore() {
    return {
      'type':
          type == CapacityType.offer ? 'offer' : 'need',
      'status': statusToString(status),
      'availabilityType': _availabilityToString(),
      'title': title,
      'description': description,
      'trade': trade,
      'location': location,
      'workerCount': workerCount,
      'availableFrom': Timestamp.fromDate(availableFrom),
      'availableTo': Timestamp.fromDate(availableTo),
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'interestCount': interestCount,
      'contentFlagged': contentFlagged,
      'posterVerified': posterVerified,
      'posterRatingSum': posterRatingSum,
      'posterRatingCount': posterRatingCount,
      'posterSuspended': posterSuspended,
      if (posterAvgResponseHours != null) 'posterAvgResponseHours': posterAvgResponseHours,
      if (districtCoordinates != null) 'districtCoordinates': districtCoordinates,
      'dayRateBand': dayRateBand,
      'skillDetails': skillDetails,
      'visibilityMode': visibilityModeToString(visibilityMode),
      if (posterCompanyId != null) 'posterCompanyId': posterCompanyId,
      if (posterCompanyName != null) 'posterCompanyName': posterCompanyName,
      if (posterLogoUrl != null) 'posterLogoUrl': posterLogoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'availabilityConfirmedAt': FieldValue.serverTimestamp(),
    };
  }

  /// For editing an existing posting's content. Deliberately excludes
  /// viewCount/favoriteCount/interestCount/companyVerified (managed by
  /// dedicated increment/admin calls) and createdAt/closedAt/cancelledAt
  /// (managed by updateStatus()) — Firestore's update() only touches keys
  /// present here, so omitting them leaves the existing values untouched.
  /// contentFlagged IS included here (unlike those) because it's derived
  /// from the description text itself and must be recomputed whenever
  /// that text changes.
  Map<String, dynamic> toFirestoreForUpdate() {
    return {
      'type':
          type == CapacityType.offer ? 'offer' : 'need',
      'status': statusToString(status),
      'availabilityType': _availabilityToString(),
      'title': title,
      'description': description,
      'trade': trade,
      'location': location,
      'workerCount': workerCount,
      'availableFrom': Timestamp.fromDate(availableFrom),
      'availableTo': Timestamp.fromDate(availableTo),
      'contentFlagged': contentFlagged,
      // Recomputed by the caller from the (possibly-changed) location string
      // before this is built — see CapacityModel.coordinatesForLocation.
      // FieldValue.delete() rather than omitting the key: if location was
      // edited away from a known district back to unrecognized free text,
      // the stale coordinates must be cleared, not left pointing at the OLD
      // district.
      'districtCoordinates': districtCoordinates ?? FieldValue.delete(),
      'dayRateBand': dayRateBand,
      'skillDetails': skillDetails,
      // Bump freshness on every edit — drives the "Aktualisiert …" label.
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ─── Static helpers ───

  static CapacityStatus _statusFromString(String s) {
    switch (s) {
      case 'inProgress':
        return CapacityStatus.inProgress;
      case 'closed':
        return CapacityStatus.closed;
      case 'cancelled':
        return CapacityStatus.cancelled;
      default:
        return CapacityStatus.active;
    }
  }

  // Missing/unrecognized ⇒ anonymous. Every document written before this
  // field existed really was 100% anonymous — that's the only truthful
  // default — and it's also fail-closed for any future malformed doc: never
  // accidentally leaks identity that was never validated.
  static CapacityVisibilityMode _visibilityModeFromString(String? s) {
    switch (s) {
      case 'visible':
        return CapacityVisibilityMode.visible;
      case 'discreet':
        return CapacityVisibilityMode.discreet;
      default:
        return CapacityVisibilityMode.anonymous;
    }
  }

  static String visibilityModeToString(CapacityVisibilityMode m) {
    switch (m) {
      case CapacityVisibilityMode.visible:
        return 'visible';
      case CapacityVisibilityMode.discreet:
        return 'discreet';
      case CapacityVisibilityMode.anonymous:
        return 'anonymous';
    }
  }

  static String statusToString(CapacityStatus s) {
    switch (s) {
      case CapacityStatus.inProgress:
        return 'inProgress';
      case CapacityStatus.closed:
        return 'closed';
      case CapacityStatus.cancelled:
        return 'cancelled';
      default:
        return 'active';
    }
  }

  String _availabilityToString() {
    switch (availabilityType) {
      case AvailabilityType.now:
        return 'now';
      case AvailabilityType.nextWeek:
        return 'nextWeek';
      case AvailabilityType.custom:
        return 'custom';
      default:
        return 'thisWeek';
    }
  }

  // ─── Computed properties ───

  bool get isActive =>
      status == CapacityStatus.active;

  bool get isInProgress =>
      status == CapacityStatus.inProgress;

  bool get isClosed =>
      status == CapacityStatus.closed;

  bool get isCancelled =>
      status == CapacityStatus.cancelled;

  /// True if post should appear in main feed
  bool get isActiveInFeed =>
      status == CapacityStatus.active ||
      status == CapacityStatus.inProgress;

  bool get isLive {
  if (createdAt == null) return false;
  return DateTime.now().difference(createdAt!).inMinutes < 30;
}

bool get isNew {
  if (createdAt == null) return false;
  return DateTime.now().difference(createdAt!).inHours < 2;
}

  /// Days until the availability window ends — perishability, the strongest
  /// honest urgency in a real-time capacity market. null once past.
  int? get daysLeft {
    final hours = availableTo.difference(DateTime.now()).inHours;
    if (hours < 0) return null;
    return (hours / 24).ceil();
  }

  /// Availability re-confirmed within the last day — "heute bestätigt".
  bool get confirmedToday {
    final ts = availabilityConfirmedAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts).inHours < 24;
  }

  String statusLabel(AppLocalizations l) {
    switch (status) {
      case CapacityStatus.inProgress:
        return l.statusInProgressBadge;
      case CapacityStatus.closed:
        return l.statusAwardedBadge;
      case CapacityStatus.cancelled:
        return l.statusCancelledBadge;
      default:
        return l.statusActiveBadge;
    }
  }

  String availabilityLabel(AppLocalizations l) {
    switch (availabilityType) {
      case AvailabilityType.now:
        return l.availNowBadge;
      case AvailabilityType.thisWeek:
        return l.availThisWeekBadge;
      case AvailabilityType.nextWeek:
        return l.availNextWeekBadge;
      case AvailabilityType.custom:
        return '${l.availFromPrefix} ${availableFrom.day}.${availableFrom.month}';
    }
  }

  String typeLabel(AppLocalizations l) =>
      type == CapacityType.offer ? l.availableLabel : l.wantedLabel;

  /// Freshness signal — "Aktualisiert heute / vor N Tagen", off updatedAt
  /// (falls back to createdAt for posts predating the field). Reads as a
  /// live, maintained listing rather than a stale "gepostet vor 7d".
  String timePostedLabel(AppLocalizations l) {
    final ts = updatedAt ?? createdAt;
    if (ts == null) return '';
    final minutes = DateTime.now().difference(ts).inMinutes;
    if (minutes < 60) return l.updatedTodayLabel;
    final hours = (minutes / 60).floor();
    if (hours < 24) return l.updatedTodayLabel;
    return l.updatedDaysAgo((hours / 24).floor());
  }

  // Trade-led title ("Dachdecker verfügbar" / "Trockenbau gesucht") — leads
  // with the Gewerk, not the number. The stored `title` is a fixed-language
  // string baked in at creation, so this computed version is displayed
  // instead (always matches the current locale).
  String autoTitle(AppLocalizations l) {
    return type == CapacityType.offer
        ? l.postTitleOffer(l.tradeName(trade))
        : l.postTitleNeed(l.tradeName(trade));
  }

  /// "5 Personen · Hamburg-Harburg" — crew size + district (never a street).
  String autoSubtitle(AppLocalizations l) =>
      '$workerCount ${l.persons} · $location';
}