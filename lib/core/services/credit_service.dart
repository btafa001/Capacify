import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/credit_wallet_model.dart';

/// Vermittlung (intro-credit) wallets. The actual *spend* is not here — it must
/// happen atomically with creating the granted contact request, so that lives
/// in ContactRequestService as a single batch the rules validate end-to-end
/// (a granted request may only be created if a credit is simultaneously spent).
/// This service owns wallet lifecycle: ensure-exists and lazy monthly reset.
class CreditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('credits');

  DocumentReference<Map<String, dynamic>> walletRef(String companyId) =>
      _col.doc(companyId);

  Stream<CreditWalletModel?> walletStream(String companyId) {
    return _col.doc(companyId).snapshots().map(
        (d) => d.exists ? CreditWalletModel.fromFirestore(d) : null);
  }

  /// Ensures the wallet exists and reflects the current month. Creates it on
  /// first use with a full quota; when the month rolls over it lazily resets
  /// `remaining` back to `quota`. The Firestore rules only permit a reset that
  /// moves to a new period and sets remaining exactly to the quota, so this
  /// can't be abused to top up mid-month. Returns the effective wallet.
  Future<CreditWalletModel> ensureWallet(String companyId, {String? plan}) async {
    final ref = _col.doc(companyId);
    final period = CreditWalletModel.currentPeriod();
    final quota = quotaForPlan(plan);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'companyId': companyId,
          'period': period,
          'remaining': quota,
          'quota': quota,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return CreditWalletModel(
            companyId: companyId, period: period, remaining: quota, quota: quota);
      }
      final w = CreditWalletModel.fromFirestore(snap);
      if (w.period != period) {
        // Lazy monthly reset — new period, remaining back to the (existing) quota.
        await ref.update({
          'period': period,
          'remaining': w.quota,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return CreditWalletModel(
            companyId: companyId, period: period, remaining: w.quota, quota: w.quota);
      }
      return w;
    } catch (_) {
      // If rules deny (e.g. someone else's wallet), surface an empty wallet.
      return CreditWalletModel(
          companyId: companyId, period: period, remaining: 0, quota: quota);
    }
  }
}
