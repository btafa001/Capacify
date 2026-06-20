import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/favorite_model.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -----------------------------
  // Add a favorite
  // -----------------------------
  Future<void> addFavorite({
    required String userId,
    required String favoriteId,
    required String favoriteType,
    required String favoriteTitle,
  }) async {
    await _firestore.collection('favorites').add({
      'userId': userId,
      'favoriteId': favoriteId,
      'favoriteType': favoriteType,
      'favoriteTitle': favoriteTitle,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // -----------------------------
  // Remove a favorite
  // -----------------------------
  Future<void> removeFavorite({
    required String userId,
    required String favoriteId,
  }) async {
    final query = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .where('favoriteId', isEqualTo: favoriteId)
        .get();

    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }

  // -----------------------------
  // Check if a favorite exists
  // (Provider expects: isFavorite)
  // -----------------------------
  Future<bool> isFavorite(String favoriteId) async {
    final query = await _firestore
        .collection('favorites')
        .where('favoriteId', isEqualTo: favoriteId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  // Original method kept for compatibility
  Future<bool> isFavorited({
    required String userId,
    required String favoriteId,
  }) async {
    final query = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .where('favoriteId', isEqualTo: favoriteId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  // -----------------------------
  // Stream favorites for a user
  // (Provider expects: watchFavorites)
  // -----------------------------
  Stream<List<FavoriteModel>> watchFavorites(String userId) {
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FavoriteModel.fromFirestore(doc))
            .toList());
  }

  // Original method kept for compatibility
  Stream<List<FavoriteModel>> getFavorites(String userId) {
    return watchFavorites(userId);
  }

  // -----------------------------
  // Stream favorites by type
  // -----------------------------
  Stream<List<FavoriteModel>> getFavoritesByType(
    String userId,
    String favoriteType,
  ) {
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .where('favoriteType', isEqualTo: favoriteType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FavoriteModel.fromFirestore(doc))
            .toList());
  }
}
