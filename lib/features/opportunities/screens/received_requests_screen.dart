import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/contact_request_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/contact_request_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../shared/widgets/milestone.dart';
import '../../messaging/screens/chat_screen.dart';

/// The POSTER's inbox of incoming messages on their posts (FREE, message-first
/// flow). Pending messages show the anonymized requester + their first message
/// with Akzeptieren / Ablehnen. Accepting reveals both sides and opens the chat;
/// granted rows link straight into the conversation.
class ReceivedRequestsScreen extends ConsumerWidget {
  final bool embedded;
  const ReceivedRequestsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AnalyticsService.logScreenView('IncomingRequests');
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        automaticallyImplyLeading: !embedded,
        title: Text(l.receivedRequestsTitle,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: uid == null
          ? Center(child: Text(l.noReceivedRequestsText, style: TextStyle(color: c.textTertiary)))
          : ref.watch(receivedRequestsProvider(uid)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(
                    child: Text(l.errorWithMessage(e),
                        style: const TextStyle(color: AppColors.error))),
                data: (requests) {
                  if (requests.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(l.noReceivedRequestsText,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.textTertiary, fontSize: 14, height: 1.5)),
                      ),
                    );
                  }
                  final posts = ref.watch(myCapacitiesProvider(uid)).valueOrNull ?? [];
                  final postsById = {for (final p in posts) p.id: p};
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                    itemCount: requests.length,
                    itemBuilder: (_, i) => _RequestCard(
                      request: requests[i],
                      post: postsById[requests[i].postId],
                      posterCompanyId: uid,
                    ),
                  );
                },
              ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final ContactRequestModel request;
  final CapacityModel? post;
  final String posterCompanyId;
  const _RequestCard(
      {required this.request, required this.post, required this.posterCompanyId});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _accept() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(contactRequestServiceProvider).acceptRequest(
            requestId: widget.request.id,
            posterCompanyId: widget.posterCompanyId,
            requestCreatedAt: widget.request.createdAt,
          );
      AnalyticsService.logEvent('request_accepted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.requestAcceptedSnackbar), backgroundColor: AppColors.live));
        // Wow moment: first connection made.
        Milestone.celebrateOnce(context,
            uid: widget.posterCompanyId,
            key: 'first_connection',
            icon: Icons.handshake_outlined,
            title: l.msFirstConnTitle,
            subtitle: l.msFirstConnBody);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _decline() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(contactRequestServiceProvider).declineRequest(
            widget.request.id,
            posterCompanyId: widget.posterCompanyId,
            requestCreatedAt: widget.request.createdAt,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.requestDeclinedSnackbar), backgroundColor: AppColors.textSecondary));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    }
  }

  void _openChat() {
    final r = widget.request;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: r.id,
          myCompanyId: widget.posterCompanyId,
          otherCompanyId: r.requesterCompanyId,
          otherCompanyName: r.requesterCompanyName,
          postId: r.postId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final r = widget.request;
    final isPending = r.status == 'pending';
    final color = isPending ? AppColors.accent : AppColors.live;
    final postRef =
        widget.post?.autoTitle(l) ?? '${l.tradeName(r.trade)} · ${r.workerCount} ${l.persons}';

    // Pre-accept: the requester is anonymized to the poster (verified? + city).
    // Post-accept: their real company name is revealed.
    final anonName = r.requesterVerified
        ? l.receivedRequestVerifiedFrom(r.requesterCity)
        : l.receivedRequestFrom(r.requesterCity);
    final who = isPending ? anonName : r.requesterCompanyName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPending ? color.withOpacity(0.4) : c.border, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Status + post reference
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Text(
              isPending ? l.receivedStatusPendingLabel : l.receivedStatusGrantedLabel,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text('${l.receivedRequestForPostLabel}: $postRef',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(color: c.textTertiary, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 10),
        // Who (anonymized until accept)
        Row(children: [
          Icon(isPending ? Icons.business_outlined : Icons.verified_user_outlined,
              size: 16, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(who,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          if (r.requesterRatingCount > 0) ...[
            const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
            const SizedBox(width: 2),
            Text((r.requesterRatingSum / r.requesterRatingCount).toStringAsFixed(1),
                style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ]),
        // The first message
        if (r.message.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Text('"${r.message.trim()}"',
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
          ),
        ],
        const SizedBox(height: 12),
        // Actions
        if (isPending)
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _decline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.textSecondary,
                  side: BorderSide(color: c.border),
                  minimumSize: const Size.fromHeight(42),
                ),
                child: Text(l.declineRequestButton),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _accept,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(l.acceptRequestButton, style: const TextStyle(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.live,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                ),
              ),
            ),
          ])
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: Text(l.sendMessageButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
      ]),
    );
  }
}
