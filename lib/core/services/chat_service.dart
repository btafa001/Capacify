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

  /// Sends a message and, in one batch, updates the thread preview + bumps the
  /// recipient's unread counter + clears the sender's typing flag.
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
