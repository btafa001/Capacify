import 'package:cloud_firestore/cloud_firestore.dart';
import '../localization/app_localizations.dart';

enum CapacityType { offer, need }

enum CapacityStatus {
  active,
  inProgress,
  closed,
  cancelled,
}

enum AvailabilityType { now, thisWeek, nextWeek, custom }

class CapacityModel {
  final String id;
  final String companyId;
  final String companyName;
  final String companyCity;
  final String companyPhone;
  final String companyEmail;
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
  final bool companyVerified;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final DateTime? cancelledAt;
  final int? dealNumber;
  final bool contentFlagged;

  CapacityModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.companyCity,
    required this.companyPhone,
    required this.companyEmail,
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
    this.companyVerified = false,
    this.createdAt,
    this.closedAt,
    this.cancelledAt,
    this.dealNumber,
    this.contentFlagged = false,
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
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      companyCity: data['companyCity'] ?? '',
      companyPhone: data['companyPhone'] ?? '',
      companyEmail: data['companyEmail'] ?? '',
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
      companyVerified: data['companyVerified'] as bool? ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate(),
      closedAt:
          (data['closedAt'] as Timestamp?)?.toDate(),
      cancelledAt:
          (data['cancelledAt'] as Timestamp?)?.toDate(),
      dealNumber: data['dealNumber'] as int?,
      contentFlagged: data['contentFlagged'] as bool? ?? false,
    );
  }

  // ─── toFirestore ───

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'companyCity': companyCity,
      'companyPhone': companyPhone,
      'companyEmail': companyEmail,
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
      'companyVerified': companyVerified,
      'contentFlagged': contentFlagged,
      'createdAt': FieldValue.serverTimestamp(),
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
      'companyName': companyName,
      'companyCity': companyCity,
      'companyPhone': companyPhone,
      'companyEmail': companyEmail,
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

  String timePostedLabel(AppLocalizations l) {
    if (createdAt == null) return '';
    final minutes =
        DateTime.now().difference(createdAt!).inMinutes;
    if (minutes < 1) return l.justNowLabel;
    if (minutes < 60) return l.minutesAgo(minutes);
    final hours = (minutes / 60).floor();
    if (hours < 24) return l.hoursAgo(hours);
    return l.daysAgoShort((hours / 24).floor());
  }

  // The stored `title` is a fixed-language string baked in at creation
  // time ("5 Dach gesucht"), so it never changes with the viewer's
  // locale. Display this computed version instead — it's reconstructed
  // from the same structured fields every time, so it always matches
  // the current language.
  String autoTitle(AppLocalizations l) {
    final typeWord =
        type == CapacityType.offer ? l.titleAvailableSuffix : l.titleWantedSuffix;
    return '$workerCount ${l.tradeName(trade)} $typeWord';
  }
}