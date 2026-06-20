import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

class ReportService {
  final _db = FirebaseFirestore.instance;

  Future<void> submitReport({
    required String capacityId,
    required String capacityTitle,
    required String companyId,
    required String companyName,
    required String reporterId,
    required ReportReason reason,
  }) {
    return _db.collection('reports').add({
      'capacityId': capacityId,
      'capacityTitle': capacityTitle,
      'companyId': companyId,
      'companyName': companyName,
      'reporterId': reporterId,
      'reason': reason.name,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  Stream<List<Map<String, dynamic>>> getAllReports() {
    return _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
