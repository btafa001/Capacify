import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

/// A company's monthly Vermittlung (intro-credit) wallet — one doc per company
/// at `credits/{companyId}`. `period` is a 'YYYY-MM' stamp; when the client
/// observes a stale period it lazily resets `remaining` back up to `quota`
/// (validated by the Firestore rules — the client can't grant itself credits
/// out of turn). During Early Access every company's quota is
/// [kEarlyAccessQuota].
class CreditWalletModel {
  final String companyId;
  final String period; // 'YYYY-MM'
  final int remaining;
  final int quota;

  CreditWalletModel({
    required this.companyId,
    required this.period,
    required this.remaining,
    required this.quota,
  });

  bool get hasCredits => remaining > 0;
  int get used => (quota - remaining).clamp(0, quota);

  /// The current month stamp, e.g. '2026-07'. Uses UTC to match the Firestore
  /// rules (which build the period from request.time, a UTC timestamp) — a local
  /// vs UTC month mismatch near a boundary would otherwise get the wallet
  /// create/reset denied.
  static String currentPeriod([DateTime? now]) {
    final d = (now ?? DateTime.now()).toUtc();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  }

  factory CreditWalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditWalletModel(
      companyId: doc.id,
      period: data['period'] ?? currentPeriod(),
      remaining: (data['remaining'] as num?)?.toInt() ?? 0,
      quota: (data['quota'] as num?)?.toInt() ?? kEarlyAccessQuota,
    );
  }
}
