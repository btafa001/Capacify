import 'package:cloud_firestore/cloud_firestore.dart';

/// One-directional "I don't want contact with this company" record. Doc id
/// is deterministic ({blockerCompanyId}_{blockedCompanyId}, same shape as
/// contact_requests) so create/delete/read are all simple point lookups —
/// see firestore.rules for the matching id-shape check and
/// isBlockedEitherWay(), which is what actually stops the blocked company
/// from sending (or receiving) a NEW contact_request in either direction.
class BlockService {
  final _db = FirebaseFirestore.instance;

  String _id(String blockerCompanyId, String blockedCompanyId) =>
      '${blockerCompanyId}_$blockedCompanyId';

  Future<void> blockCompany({
    required String blockerCompanyId,
    required String blockedCompanyId,
  }) {
    return _db
        .collection('userBlocks')
        .doc(_id(blockerCompanyId, blockedCompanyId))
        .set({
      'blockerCompanyId': blockerCompanyId,
      'blockedCompanyId': blockedCompanyId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockCompany({
    required String blockerCompanyId,
    required String blockedCompanyId,
  }) {
    return _db
        .collection('userBlocks')
        .doc(_id(blockerCompanyId, blockedCompanyId))
        .delete();
  }

  Stream<bool> isBlockedByMe({
    required String blockerCompanyId,
    required String blockedCompanyId,
  }) {
    return _db
        .collection('userBlocks')
        .doc(_id(blockerCompanyId, blockedCompanyId))
        .snapshots()
        .map((d) => d.exists);
  }

  /// The full set of company ids the given company has blocked — used to
  /// filter listings/directory results client-side (the rules-level check
  /// only guards NEW contact_requests, not what's shown in a browse view).
  Stream<Set<String>> blockedCompanyIds(String blockerCompanyId) {
    return _db
        .collection('userBlocks')
        .where('blockerCompanyId', isEqualTo: blockerCompanyId)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()['blockedCompanyId'] as String).toSet());
  }
}
