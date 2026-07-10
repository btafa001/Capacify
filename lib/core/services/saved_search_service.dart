import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_search_model.dart';
import 'auth_provider.dart';

class SavedSearchService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('savedSearches');

  Stream<List<SavedSearchModel>> watchMine(String ownerId) {
    return _col.where('ownerId', isEqualTo: ownerId).snapshots().map((s) {
      final list = s.docs.map(SavedSearchModel.fromFirestore).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Future<void> save(SavedSearchModel search) async {
    await _col.add(search.toFirestore());
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

final savedSearchServiceProvider =
    Provider<SavedSearchService>((ref) => SavedSearchService());

final mySavedSearchesProvider =
    StreamProvider<List<SavedSearchModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(savedSearchServiceProvider).watchMine(uid);
});
