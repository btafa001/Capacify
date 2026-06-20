import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'favorites_service.dart';
import '../models/favorite_model.dart';

final favoritesServiceProvider =
    Provider<FavoritesService>((ref) {
  return FavoritesService();
});

final userFavoritesProvider =
    StreamProvider.family<List<FavoriteModel>, String>((ref, userId) {
  return ref.watch(favoritesServiceProvider).watchFavorites(userId);
});

final isFavoriteProvider =
    FutureProvider.family<bool, String>((ref, favoriteId) async {
  return ref.watch(favoritesServiceProvider).isFavorite(favoriteId);
});