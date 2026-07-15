import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyRatingModel {
  final String id;
  final String raterUserId;
  final String raterCompanyName;
  final String companyId;
  final String ratedCompanyName;
  final int rating;
  final String comment;
  final String status; // 'pending' | 'approved' | 'rejected'
  // The granted contact_request this rating is justified by (see
  // firestore.rules isGrantedConnectionBetween) — proof the rater and rated
  // company actually connected, not just any two accounts. Required on every
  // new rating; absent on ratings written before this gate existed.
  final String viaRequestId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  CompanyRatingModel({
    required this.id,
    required this.raterUserId,
    required this.raterCompanyName,
    required this.companyId,
    required this.ratedCompanyName,
    required this.rating,
    required this.comment,
    this.status = 'pending',
    this.viaRequestId = '',
    this.createdAt,
    this.updatedAt,
  });

  factory CompanyRatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyRatingModel(
      id: doc.id,
      raterUserId: data['raterUserId'] ?? '',
      raterCompanyName: data['raterCompanyName'] ?? '',
      companyId: data['companyId'] ?? '',
      ratedCompanyName: data['ratedCompanyName'] ?? '',
      rating: data['rating'] ?? 0,
      comment: data['comment'] ?? '',
      status: data['status'] ?? 'pending',
      viaRequestId: data['viaRequestId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
