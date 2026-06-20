import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteModel {
  final String id;
  final String userId;
  final String favoriteId;
  final String favoriteType; // 'capacity' or 'company'
  final String favoriteTitle;
  final DateTime createdAt;

  FavoriteModel({
    required this.id,
    required this.userId,
    required this.favoriteId,
    required this.favoriteType,
    required this.favoriteTitle,
    required this.createdAt,
  });

  factory FavoriteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FavoriteModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      favoriteId: data['favoriteId'] ?? '',
      favoriteType: data['favoriteType'] ?? 'capacity',
      favoriteTitle: data['favoriteTitle'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'favoriteId': favoriteId,
      'favoriteType': favoriteType,
      'favoriteTitle': favoriteTitle,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}