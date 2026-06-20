import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportReason {
  spam,
  wrongInformation,
  fakeCompany,
  offensiveContent,
  suspiciousBehavior,
}

extension ReportReasonLabel on ReportReason {
  String get label {
    switch (this) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.wrongInformation:
        return 'Falsche Informationen';
      case ReportReason.fakeCompany:
        return 'Fake-Unternehmen';
      case ReportReason.offensiveContent:
        return 'Anstößiger Inhalt';
      case ReportReason.suspiciousBehavior:
        return 'Verdächtiges Verhalten';
    }
  }
}

class ReportModel {
  final String id;
  final String capacityId;
  final String capacityTitle;
  final String companyId;
  final String companyName;
  final String reporterId;
  final ReportReason reason;
  final DateTime createdAt;
  final String status;

  const ReportModel({
    required this.id,
    required this.capacityId,
    required this.capacityTitle,
    required this.companyId,
    required this.companyName,
    required this.reporterId,
    required this.reason,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toFirestore() => {
        'capacityId': capacityId,
        'capacityTitle': capacityTitle,
        'companyId': companyId,
        'companyName': companyName,
        'reporterId': reporterId,
        'reason': reason.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status,
      };
}
