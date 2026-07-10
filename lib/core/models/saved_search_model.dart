import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved feed filter — the seed of the retention loop. Persisted so a user
/// can re-check "their" slice of the market in one tap, and (later) receive an
/// email/push when a new capacity matches it. Deliberately mirrors the feed's
/// own filter state.
class SavedSearchModel {
  final String id;
  final String ownerId;
  final List<String> trades; // empty = any trade
  final String when; // 'Alle' | 'NOW' | 'WEEK' | 'NEXT'
  final int crewMin; // 0 = any
  final String type; // 'all' | 'offer' | 'need'
  final DateTime? createdAt;

  SavedSearchModel({
    required this.id,
    required this.ownerId,
    this.trades = const [],
    this.when = 'Alle',
    this.crewMin = 0,
    this.type = 'all',
    this.createdAt,
  });

  factory SavedSearchModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SavedSearchModel(
      id: doc.id,
      ownerId: d['ownerId'] ?? '',
      trades: List<String>.from(d['trades'] ?? const []),
      when: d['when'] ?? 'Alle',
      crewMin: (d['crewMin'] as num?)?.toInt() ?? 0,
      type: d['type'] ?? 'all',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'trades': trades,
        'when': when,
        'crewMin': crewMin,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
