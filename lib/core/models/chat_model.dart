import 'package:cloud_firestore/cloud_firestore.dart';

/// A 1:1 conversation between the two parties of a *granted* contact request.
/// Doc id == the contact_request id (`{requesterCompanyId}_{postId}`), so the
/// rules can confirm the chat corresponds to a real, accepted connection.
/// A chat only ever exists AFTER acceptance, when both identities are already
/// revealed — so there's no anonymization concern inside the thread.
class ChatModel {
  final String id;
  final List<String> participants; // [requesterCompanyId, posterCompanyId]
  final String postId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastMessageSender;
  final DateTime? createdAt;
  // Per-participant state, all keyed by company id:
  final Map<String, int> unread; // undelivered-to-me count
  final Map<String, DateTime> reads; // when each party last opened the thread
  final Map<String, DateTime> typing; // last "is typing" heartbeat

  ChatModel({
    required this.id,
    required this.participants,
    required this.postId,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastMessageSender = '',
    this.createdAt,
    this.unread = const {},
    this.reads = const {},
    this.typing = const {},
  });

  /// The other participant's company id, from the viewer's perspective.
  String otherParticipant(String myId) =>
      participants.firstWhere((p) => p != myId, orElse: () => '');

  int unreadFor(String myId) => unread[myId] ?? 0;
  bool hasUnread(String myId) => unreadFor(myId) > 0;

  /// True if the other party has a fresh "typing" heartbeat (< 5s old).
  bool isOtherTyping(String myId) {
    final t = typing[otherParticipant(myId)];
    if (t == null) return false;
    return DateTime.now().difference(t).inSeconds < 5;
  }

  /// When the other party last read the thread — drives "Gelesen" receipts.
  DateTime? lastReadBy(String companyId) => reads[companyId];

  static Map<String, DateTime> _readMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, DateTime>{};
    raw.forEach((k, v) {
      if (v is Timestamp) out[k as String] = v.toDate();
    });
    return out;
  }

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawUnread = data['unread'];
    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? const []),
      postId: data['postId'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSender: data['lastMessageSender'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      unread: rawUnread is Map
          ? rawUnread.map((k, v) => MapEntry(k as String, (v as num).toInt()))
          : const {},
      reads: _readMap(data['reads']),
      typing: _readMap(data['typing']),
    );
  }
}

/// One message in a chat. `participants` is denormalized from the parent chat
/// so the read rule is a cheap membership check (no per-message get()); on
/// create the rule verifies it matches the chat's participants.
class ChatMessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
