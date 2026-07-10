import 'package:cloud_firestore/cloud_firestore.dart';

/// The LOCKED identity sidecar for a post. One per capacities/{postId}, stored
/// at capacityOwners/{postId}. This is the ONLY place a post's poster identity
/// lives. Firestore rules release it only to the owner, an admin, or a
/// requester holding a *granted* contact request for this exact post — so an
/// ungranted client can never read it (enforced on Google's servers, not in
/// the UI). Contact is a snapshot taken at post time (the poster's chosen
/// method), kept here rather than re-read from the company doc at grant time.
class CapacityOwnerModel {
  final String postId;
  final String posterCompanyId;
  final String companyName;
  final String contactPhone;
  final String contactEmail;
  final DateTime? createdAt;

  CapacityOwnerModel({
    required this.postId,
    required this.posterCompanyId,
    required this.companyName,
    required this.contactPhone,
    required this.contactEmail,
    this.createdAt,
  });

  factory CapacityOwnerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CapacityOwnerModel(
      postId: doc.id,
      posterCompanyId: data['posterCompanyId'] ?? '',
      companyName: data['companyName'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      contactEmail: data['contactEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'posterCompanyId': posterCompanyId,
      'companyName': companyName,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
