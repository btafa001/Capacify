import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/chat_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/contact_request_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/report_provider.dart';
import '../../../core/models/report_model.dart';
import '../../../core/utils/content_moderation.dart';
import '../../../shared/widgets/milestone.dart';

/// 1:1 thread for an accepted connection, with unread tracking, read receipts,
/// typing indicators, date separators and light profanity moderation. Both
/// parties are already known to each other here, so nothing is hidden.
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String myCompanyId;
  final String otherCompanyId;
  final String otherCompanyName;
  final String postId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.myCompanyId,
    required this.otherCompanyId,
    required this.otherCompanyName,
    required this.postId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  bool _sending = false;
  DateTime? _lastTypingSent;
  // Gates watching the chat doc/messages until ensureChat()'s create has
  // actually landed. messages/{messageId}'s read rule get()s the PARENT chat
  // doc — on a brand-new chat (first-ever contact between two companies),
  // watching messages before that parent exists denies the WHOLE listener,
  // and Firestore doesn't auto-retry a denied snapshot listener on its own.
  // That's what showed up as one side of a first contact being unable to
  // open the chat at all, while the separately-delivered push notification
  // still arrived fine — it self-"fixed" only once something else (like
  // navigating away and back) remounted this screen after the doc existed.
  bool _chatReady = false;

  List<String> get _participants => [widget.myCompanyId, widget.otherCompanyId];

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('Chat');
    // Create the thread lazily, then mark it read for me.
    ref
        .read(chatServiceProvider)
        .ensureChat(
          chatId: widget.chatId,
          participants: _participants,
          postId: widget.postId,
        )
        .then((_) async {
      ref.read(chatServiceProvider).markRead(chatId: widget.chatId, uid: widget.myCompanyId);
      if (mounted) setState(() => _chatReady = true);
      // Denormalize my own Ansprechpartner name onto the thread so the other
      // side can see who they're talking to — users/{uid} is owner-private, so
      // they can't read it live. Best-effort; company id == my uid (1:1).
      final profile =
          await ref.read(authServiceProvider).getUserProfile(widget.myCompanyId);
      final myName = [
        (profile?['firstName'] as String?)?.trim() ?? '',
        (profile?['lastName'] as String?)?.trim() ?? '',
      ].where((s) => s.isNotEmpty).join(' ');
      if (myName.isNotEmpty) {
        await ref.read(chatServiceProvider).setContactName(
              chatId: widget.chatId,
              uid: widget.myCompanyId,
              name: myName,
            );
      }
    });
    // Also mark the underlying contact_request "seen" for my_capacities_
    // screen.dart's re-engagement badge — harmless no-op if I'm the
    // requester, not the poster (firestore.rules only allows the poster to
    // set this, and markSeenByPoster swallows the resulting rejection; no
    // client-side role check needed).
    ref.read(contactRequestServiceProvider).markSeenByPoster(widget.chatId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Debounced typing heartbeat (at most one write / 3s while there's text).
  void _onChanged(String value) {
    if (value.trim().isEmpty) return;
    final now = DateTime.now();
    if (_lastTypingSent == null ||
        now.difference(_lastTypingSent!).inSeconds >= 3) {
      _lastTypingSent = now;
      ref
          .read(chatServiceProvider)
          .setTyping(chatId: widget.chatId, uid: widget.myCompanyId);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final l = AppLocalizations.of(context);
    // Light moderation — both parties are already connected, so this is just a
    // profanity/abuse guard, not an identity check.
    if (containsBlockedContent(text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.messageBlockedSnackbar), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _sending = true);
    _controller.clear();
    _lastTypingSent = null;
    try {
      await ref.read(chatServiceProvider).sendMessage(
            chatId: widget.chatId,
            senderId: widget.myCompanyId,
            participants: _participants,
            text: text,
          );
      AnalyticsService.logEvent('chat_message_sent');
    } catch (e) {
      _controller.text = text; // restore on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      // Tapping the send button (a separate focusable widget) takes keyboard
      // focus away from the composer, so without this the field looked
      // "done" after every message and needed a fresh tap before you could
      // type the next one.
      _composerFocus.requestFocus();
    }
  }

  // Report the other party from within the thread — files a report for the
  // founder to review (the chat's postId + the other company give admin the
  // context to resolve it). A reason picker keeps it one tap + one choice.
  Future<void> _reportUser() async {
    final l = AppLocalizations.of(context);
    final c = AppColors.of(context);
    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l.reportUser,
                    style: TextStyle(
                        color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
            ...ReportReason.values.map((r) => ListTile(
                  title: Text(l.reasonLabel(r), style: TextStyle(color: c.textPrimary)),
                  onTap: () => Navigator.pop(ctx, r),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await ref.read(reportServiceProvider).submitReport(
            capacityId: widget.postId,
            capacityTitle: 'Chat',
            companyId: widget.otherCompanyId,
            companyName: widget.otherCompanyName,
            reporterId: widget.myCompanyId,
            reason: reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.reportSuccess), backgroundColor: AppColors.live));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    }
  }

  // Only ever reachable once the underlying post is closed/cancelled (see
  // the menu item's own gating in build()) — deleteChat re-checks that
  // server-side regardless. Chats can't be deleted directly by the client
  // (firestore.rules: allow delete: if false, since the messages
  // subcollection needs a recursive delete only the Admin SDK can do), so
  // this goes through a Cloud Function, same pattern as purgeUserData.
  Future<void> _deleteChat() async {
    final l = AppLocalizations.of(context);
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(l.deleteChatConfirmTitle,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
        content: Text(l.deleteChatConfirmBody,
            style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteButton, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('deleteChat')
          .call({'chatId': widget.chatId});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  String _dateLabel(DateTime d, AppLocalizations l) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return l.dateTodayLabel;
    if (diff == 1) return l.dateYesterdayLabel;
    return '${d.day}.${d.month}.${d.year}';
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    // Delete is only ever offered once the match is actually done — while a
    // post is still active/in-progress either side might still need the
    // thread.
    final post = ref.watch(capacityByIdProvider(widget.postId)).valueOrNull;
    final canDelete = post != null && (post.isClosed || post.isCancelled);
    final company = ref.watch(companyByIdProvider(widget.otherCompanyId)).valueOrNull;
    final title = (company?.name.isNotEmpty ?? false)
        ? company!.name
        : (widget.otherCompanyName.isNotEmpty
            ? widget.otherCompanyName
            : l.chatFallbackTitle);

    // Not watched until ensureChat() has confirmed the parent chat doc
    // exists — see _chatReady's doc comment.
    final chat = _chatReady ? ref.watch(chatDocProvider(widget.chatId)).valueOrNull : null;
    final otherTyping = chat?.isOtherTyping(widget.myCompanyId) ?? false;
    final otherReadAt = chat?.lastReadBy(widget.otherCompanyId);
    // The human Ansprechpartner on the other side (shown under the company name
    // so you know WHO you're talking to, not just which firm). Null until they
    // first open the thread — the company name alone carries it fine until then.
    final otherContactName = chat?.contactNameFor(widget.otherCompanyId);

    // Keep the thread marked read while I'm looking at it.
    if (chat != null && chat.unreadFor(widget.myCompanyId) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref
          .read(chatServiceProvider)
          .markRead(chatId: widget.chatId, uid: widget.myCompanyId));
    }

    // Same _chatReady gating as chat above — only non-null once ensureChat()
    // has confirmed the parent doc exists, so it's safe to force-unwrap
    // wherever it's used below (only ever reached in the _chatReady branch).
    final messagesAsync = _chatReady ? ref.watch(chatMessagesProvider(widget.chatId)) : null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 15.5)),
                  if (otherTyping)
                    Text(l.typingLabel,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600))
                  else if (otherContactName != null)
                    Text(otherContactName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            color: c.surface,
            icon: Icon(Icons.more_vert, color: c.textSecondary),
            onSelected: (v) {
              if (v == 'report') _reportUser();
              if (v == 'delete') _deleteChat();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'report',
                child: Row(children: [
                  const Icon(Icons.flag_outlined, size: 18, color: AppColors.error),
                  const SizedBox(width: 10),
                  Text(l.reportUser, style: TextStyle(color: c.textPrimary)),
                ]),
              ),
              // Only offered once the match is closed/cancelled.
              if (canDelete)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text(l.deleteChatAction, style: TextStyle(color: c.textPrimary)),
                  ]),
                ),
            ],
          ),
        ],
      ),
      // The thread lives in a centered, width-capped panel so it reads like a
      // conversation, not a full-width page, on desktop.
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          decoration: MediaQuery.of(context).size.width > 680
              ? BoxDecoration(
                  color: c.surface.withOpacity(0.35),
                  border: Border.symmetric(vertical: BorderSide(color: c.border)),
                )
              : null,
          child: !_chatReady
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Column(
        children: [
          _CollabBanner(chatId: widget.chatId, myCompanyId: widget.myCompanyId),
          Expanded(
            child: messagesAsync!.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                  child: Text(l.errorWithMessage(e),
                      style: const TextStyle(color: AppColors.error))),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l.noMessagesYet,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textTertiary, fontSize: 14, height: 1.5)),
                    ),
                  );
                }
                _jumpToBottom();
                // Index of my last message → the only place a receipt shows.
                int myLast = -1;
                for (var i = messages.length - 1; i >= 0; i--) {
                  if (messages[i].senderId == widget.myCompanyId) {
                    myLast = i;
                    break;
                  }
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final mine = m.senderId == widget.myCompanyId;
                    final showDate =
                        i == 0 || !_sameDay(messages[i - 1].createdAt, m.createdAt);
                    // Name the person behind an incoming message at the start of
                    // each run (sender change or new day). Only the other side is
                    // labelled — your own messages don't need a "you". Forward-
                    // compatible with multiple people per company later.
                    final startOfRun = i == 0 ||
                        messages[i - 1].senderId != m.senderId ||
                        showDate;
                    final showSender =
                        !mine && startOfRun && otherContactName != null;
                    String? receipt;
                    if (mine && i == myLast) {
                      final seen = otherReadAt != null &&
                          m.createdAt != null &&
                          otherReadAt.isAfter(m.createdAt!);
                      receipt = seen ? l.seenReceipt : l.deliveredReceipt;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDate && m.createdAt != null)
                          _DateChip(label: _dateLabel(m.createdAt!, l)),
                        if (showSender)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, top: 6, bottom: 2),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(otherContactName!,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: c.textTertiary,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        _Bubble(text: m.text, at: m.createdAt, mine: mine, receipt: receipt),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Composer
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.border)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _composerFocus,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: c.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: l.messageHint,
                        hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
                        filled: true,
                        fillColor: c.background,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: c.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: c.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : _send,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final DateTime? at;
  final bool mine;
  final String? receipt;

  const _Bubble({required this.text, required this.at, required this.mine, this.receipt});

  String _time(DateTime? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            // Absolute cap keeps bubbles compact inside the centered panel.
            constraints: BoxConstraints(
                maxWidth: (MediaQuery.of(context).size.width * 0.75).clamp(0, 440)),
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: mine ? AppColors.primary : c.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(mine ? 14 : 4),
                bottomRight: Radius.circular(mine ? 4 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(text,
                    style: TextStyle(
                        color: mine ? Colors.white : c.textPrimary, fontSize: 13.5, height: 1.35)),
                const SizedBox(height: 2),
                Text(_time(at),
                    style: TextStyle(
                        color: mine ? Colors.white.withOpacity(0.7) : c.textTertiary, fontSize: 10)),
              ],
            ),
          ),
        ),
        if (receipt != null)
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    receipt == AppLocalizations.of(context).seenReceipt
                        ? Icons.done_all
                        : Icons.done,
                    size: 13,
                    color: receipt == AppLocalizations.of(context).seenReceipt
                        ? AppColors.primary
                        : c.textTertiary),
                const SizedBox(width: 3),
                Text(receipt!,
                    style: TextStyle(color: c.textTertiary, fontSize: 10.5)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Prompts for what actually happened (CapacityOS outcome data) before
/// confirming a collaboration — crew size prefilled from the original post,
/// duration optional. Returns null only if the dialog is dismissed entirely
/// (Cancel/tap-outside); tapping the primary button always returns a result,
/// using whatever's currently in the fields — nothing here is required.
Future<({int crewSize, int? durationDays})?> _promptCollabOutcome(
  BuildContext context,
  AppLocalizations l, {
  required int defaultCrewSize,
}) {
  final crewController = TextEditingController(text: defaultCrewSize.toString());
  final durationController = TextEditingController();
  return showDialog<({int crewSize, int? durationDays})>(
    context: context,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      return AlertDialog(
        backgroundColor: c.surface,
        title: Text(l.collabOutcomeDialogTitle,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.collabOutcomeDialogBody,
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: crewController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.collabActualCrewSizeLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.collabActualDurationLabel),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final crewSize = int.tryParse(crewController.text.trim()) ?? defaultCrewSize;
              final durationDays = int.tryParse(durationController.text.trim());
              Navigator.pop(ctx, (crewSize: crewSize, durationDays: durationDays));
            },
            child: Text(l.collabConfirmButton),
          ),
        ],
      );
    },
  ).whenComplete(() {
    crewController.dispose();
    durationController.dispose();
  });
}

/// Mutual "we worked together" confirmation, shown at the top of a granted
/// connection's chat. Each side confirms once; when both have, a Cloud Function
/// counts the completed collaboration for both companies (trust + CapacityOS).
class _CollabBanner extends ConsumerWidget {
  final String chatId; // == the contact_request id
  final String myCompanyId;
  const _CollabBanner({required this.chatId, required this.myCompanyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final req = ref.watch(contactRequestByIdProvider(chatId)).valueOrNull;
    if (req == null || req.status != 'granted') return const SizedBox.shrink();

    final isRequester = req.requesterCompanyId == myCompanyId;
    final iConfirmed = isRequester ? req.collabRequester : req.collabPoster;

    // Urgent marker — reuses this already-watched request doc rather than
    // threading a new param through every ChatScreen call site. A chat can
    // only ever be open once a request is granted (regardless of mode), so
    // there's no separate "still pending" case to worry about here — this
    // reads correctly whether the grant came from an Accept (anonymous) or
    // was instant (visible/discreet).
    final urgentChip = req.urgent
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.error.withOpacity(0.08),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 5),
              Text(l.urgentRequestBadge,
                  style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
            ]),
          )
        : null;

    Widget wrap(Widget banner) => urgentChip == null
        ? banner
        : Column(mainAxisSize: MainAxisSize.min, children: [urgentChip, banner]);

    if (req.collabConfirmed) {
      return wrap(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.live.withOpacity(0.10),
        child: Row(children: [
          const Icon(Icons.verified_rounded, size: 16, color: AppColors.live),
          const SizedBox(width: 8),
          Text(l.collabConfirmedBoth,
              style: const TextStyle(color: AppColors.live, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      ));
    }

    if (iConfirmed) {
      return wrap(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: c.surfaceVariant,
        child: Row(children: [
          Icon(Icons.hourglass_top_rounded, size: 15, color: c.textTertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(l.collabWaitingPartner,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
        ]),
      ));
    }

    return wrap(Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        border: Border(bottom: BorderSide(color: AppColors.primary.withOpacity(0.20))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.handshake_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.collabPromptTitle,
                      style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(l.collabPromptBody,
                      style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.3)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () async {
                final outcome = await _promptCollabOutcome(context, l, defaultCrewSize: req.workerCount);
                if (outcome == null || !context.mounted) return;
                final otherAlready = isRequester ? req.collabPoster : req.collabRequester;
                try {
                  await ref.read(contactRequestServiceProvider).confirmCollaboration(
                        requestId: chatId,
                        asPoster: !isRequester,
                        actualCrewSize: outcome.crewSize,
                        actualDurationDays: outcome.durationDays,
                      );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.collabConfirmSnackbar), backgroundColor: AppColors.live),
                  );
                  // If the partner had already confirmed, this completes it → wow.
                  if (otherAlready) {
                    Milestone.celebrateOnce(context,
                        uid: myCompanyId,
                        key: 'first_collab',
                        icon: Icons.verified_rounded,
                        title: l.msFirstCollabTitle,
                        subtitle: l.msFirstCollabBody);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check_rounded, size: 17),
              label: Text(l.collabConfirmButton,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    ));
  }
}
