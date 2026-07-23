import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

class ReportService {
  final _db = FirebaseFirestore.instance;

  // UTC 'YYYY-MM-DD' — matches the server request.time used by the throttle
  // rule (same helper as CapacityService._todayStr).
  String _todayStr() {
    final n = DateTime.now().toUtc();
    final mm = n.month.toString().padLeft(2, '0');
    final dd = n.day.toString().padLeft(2, '0');
    return '${n.year}-$mm-$dd';
  }

  /// Files a report and, in the same batch, bumps the reporter's daily
  /// counter (previously uncapped — see reportCounts in firestore.rules).
  Future<void> submitReport({
    required String capacityId,
    required String capacityTitle,
    required String companyId,
    required String companyName,
    required String reporterId,
    required ReportReason reason,
  }) async {
    final today = _todayStr();
    final countRef = _db.collection('reportCounts').doc(reporterId);
    final countSnap = await countRef.get();
    final sameDay = countSnap.exists && countSnap.data()?['day'] == today;
    final newCount = sameDay ? ((countSnap.data()?['count'] ?? 0) as int) + 1 : 1;

    final batch = _db.batch();
    batch.set(_db.collection('reports').doc(), {
      'capacityId': capacityId,
      'capacityTitle': capacityTitle,
      'companyId': companyId,
      'companyName': companyName,
      'reporterId': reporterId,
      'reason': reason.name,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    batch.set(countRef, {'day': today, 'count': newCount});
    await batch.commit();
  }

  Stream<List<ReportModel>> getAllReports() {
    return _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReportModel.fromFirestore).toList());
  }

  /// Admin-only (see firestore.rules) transition out of 'pending' — 'resolved'
  /// once the report's been acted on, 'dismissed' if it wasn't actionable.
  Future<void> setReportStatus(String reportId, String status) {
    return _db.collection('reports').doc(reportId).update({'status': status});
  }
}
