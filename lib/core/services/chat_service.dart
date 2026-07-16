import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

/// In-app messaging between the two parties of a granted contact request.
/// The thread doc lives at `chats/{requestId}`, messages at
/// `chats/{requestId}/messages/{id}`. Access is enforced in firestore.rules:
/// a chat can only be created for a `granted` request and only its two
/// participants may read/write it.
class ChatService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chats => _fs.collection('chats');

  /// Lazily creates the chat thread the first time either party opens it.
  /// Works for any already-granted request (not just fresh accepts). No-op if
  /// it already exists. `participants` must be the request's requester + poster.
  Future<void> ensureChat({
    required String chatId,
    required List<String> participants,
    required String postId,
  }) async {
    final ref = _chats.doc(chatId);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'participants': participants,
      'postId': postId,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Denormalizes MY own Ansprechpartner name onto the thread so the other
  /// party (who can't read my owner-private users/{uid} doc) can see who they're
  /// talking to. Only ever writes my own entry; the chat must already exist
  /// (call after ensureChat) so this stays an update, not a rules-rejected
  /// create. Best-effort — a failure just leaves the name unshown.
  Future<void> setContactName({
    required String chatId,
    required String uid,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await _chats.doc(chatId).update({'contactNames.$uid': trimmed});
    } catch (_) {
      // Thread not created yet, or a transient rules/network hiccup — the name
      // is a nice-to-have, never worth surfacing an error for.
    }
  }

  /// Live doc stream for one thread — drives unread/read-receipt/typing state.
  Stream<ChatModel?> chatDoc(String chatId) {
    return _chats
        .doc(chatId)
        .snapshots()
        .map((d) => d.exists ? ChatModel.fromFirestore(d) : null);
  }

  Stream<List<ChatMessageModel>> messages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(ChatMessageModel.fromFirestore).toList());
  }

  // UTC 'YYYY-MM-DD' — matches the server request.time used by the throttle
  // rule (same helper as CapacityService._todayStr).
  String _todayStr() {
    final n = DateTime.now().toUtc();
    final mm = n.month.toString().padLeft(2, '0');
    final dd = n.day.toString().padLeft(2, '0');
    return '${n.year}-$mm-$dd';
  }

  /// Sends a message and, in one batch, updates the thread preview + bumps the
  /// recipient's unread counter + clears the sender's typing flag + bumps the
  /// sender's daily message counter (previously uncapped — see
  /// messageCounts in firestore.rules; exceeding it fails the whole batch,
  /// same atomic-throttle pattern as CapacityService.createCapacity).
  /// `participants` is denormalized onto the message so reads stay a cheap
  /// membership check.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required List<String> participants,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final otherId =
        participants.firstWhere((p) => p != senderId, orElse: () => '');

    final today = _todayStr();
    final countRef = _fs.collection('messageCounts').doc(senderId);
    final countSnap = await countRef.get();
    final sameDay = countSnap.exists && countSnap.data()?['day'] == today;
    final newCount = sameDay ? ((countSnap.data()?['count'] ?? 0) as int) + 1 : 1;

    final batch = _fs.batch();
    final msgRef = _chats.doc(chatId).collection('messages').doc();
    batch.set(msgRef, {
      'senderId': senderId,
      'participants': participants,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_chats.doc(chatId), {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSender': senderId,
      if (otherId.isNotEmpty) 'unread.$otherId': FieldValue.increment(1),
      'typing.$senderId': FieldValue.delete(),
    });
    batch.set(countRef, {'day': today, 'count': newCount});
    await batch.commit();
  }

  /// Marks the thread read for [uid]: clears their unread counter and stamps
  /// their read time (which the other party sees as a "Gelesen" receipt).
  Future<void> markRead({required String chatId, required String uid}) async {
    try {
      await _chats.doc(chatId).update({
        'unread.$uid': 0,
        'reads.$uid': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Heartbeats a "typing" timestamp for [uid]. Call debounced (~every 3s while
  /// actively typing); the other side treats a heartbeat < 5s old as "typing".
  Future<void> setTyping({required String chatId, required String uid}) async {
    try {
      await _chats
          .doc(chatId)
          .update({'typing.$uid': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  /// All of a company's conversations, newest activity first (inbox).
  Stream<List<ChatModel>> myChats(String companyId) {
    return _chats
        .where('participants', arrayContains: companyId)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ChatModel.fromFirestore).toList();
      list.sort((a, b) => (b.lastMessageAt ?? DateTime(0))
          .compareTo(a.lastMessageAt ?? DateTime(0)));
      return list;
    });
  }
}
