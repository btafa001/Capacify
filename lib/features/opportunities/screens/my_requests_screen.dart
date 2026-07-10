import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/contact_request_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/contact_request_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../messaging/screens/chat_screen.dart';

/// The requester's own sent contact requests, shown as a compact tile grid
/// (same look as the company directory). After an unlock, the requester
/// records how it went ("Hat's geklappt?").
class MyRequestsScreen extends ConsumerWidget {
  final bool embedded;
  const MyRequestsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AnalyticsService.logScreenView('MyRequests');
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        automaticallyImplyLeading: !embedded,
        title: Text(l.myRequestsTitle,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: uid == null
          ? Center(child: Text(l.noRequestsYetText, style: TextStyle(color: c.textTertiary)))
          : ref.watch(myContactRequestsProvider(uid)).when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text(l.errorWithMessage(e), style: const TextStyle(color: AppColors.error))),
                data: (requests) {
                  if (requests.isEmpty) {
                    return Center(child: Text(l.noRequestsYetText, style: TextStyle(color: c.textTertiary, fontSize: 14)));
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 185,
                        ),
                        itemCount: requests.length,
                        itemBuilder: (_, i) => _MyRequestTile(request: requests[i]),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _MyRequestTile extends ConsumerStatefulWidget {
  final ContactRequestModel request;
  const _MyRequestTile({required this.request});

  @override
  ConsumerState<_MyRequestTile> createState() => _MyRequestTileState();
}

class _MyRequestTileState extends ConsumerState<_MyRequestTile> {
  bool _hovered = false;

  Color _statusColor(BuildContext context, String status) => status == 'granted'
      ? AppColors.live
      : status == 'declined'
          ? AppColors.error
          : status == 'pending_review'
              ? AppColors.accent
              : status == 'closed'
                  ? AppColors.of(context).textTertiary
                  : AppColors.primary;

  void _openChat(ContactRequestModel r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: r.id,
          myCompanyId: r.requesterCompanyId,
          otherCompanyId: r.posterCompanyId!,
          otherCompanyName: '',
          postId: r.postId,
        ),
      ),
    );
  }

  Future<void> _setOutcome(String outcome) async {
    final l = AppLocalizations.of(context);
    try {
      await ref
          .read(contactRequestServiceProvider)
          .setOutcome(requestId: widget.request.id, outcome: outcome);
      // Final funnel step: post → view → reveal → message → OUTCOME.
      AnalyticsService.logEvent('vermittlung_outcome', parameters: {'outcome': outcome});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.thanksForFeedbackSnackbar), backgroundColor: AppColors.live));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final r = widget.request;
    final color = _statusColor(context, r.status);
    final canChat = r.status == 'granted' && r.posterCompanyId != null;
    // Follow-up ("Hat's geklappt?") opens ~14 days after an unlocked connection.
    final ageDays = r.createdAt == null ? 0 : DateTime.now().difference(r.createdAt!).inDays;
    final canRate = r.status == 'granted' && r.outcome == null && ageDays >= 14;
    final dateStr = r.createdAt == null ? '' : '${r.createdAt!.day}.${r.createdAt!.month}.';

    return MouseRegion(
      cursor: canChat ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: canChat ? () => _openChat(r) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered && canChat ? AppColors.primary.withOpacity(0.4) : c.border,
              width: 1.5,
            ),
            boxShadow: _hovered && canChat
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6))]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status chip + date
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: color.withOpacity(0.35)),
                              ),
                              child: Text(l.requestStatusShort(r.status),
                                  style: TextStyle(
                                      color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                            ),
                            const Spacer(),
                            Text(dateStr, style: TextStyle(color: c.textTertiary, fontSize: 10.5)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${l.tradeName(r.trade)} · ${r.workerCount} ${l.persons}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 13.5)),
                        if (r.message.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('"${r.message.trim()}"',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 11.5, height: 1.35, fontStyle: FontStyle.italic)),
                        ],
                        const Spacer(),
                        // Bottom action: outcome result > follow-up > chat.
                        if (r.outcome != null)
                          Text(
                              r.outcome == 'matched'
                                  ? l.outcomeMatchedLabel
                                  : r.outcome == 'open'
                                      ? l.outcomeOpenLabel
                                      : l.outcomeNoDealLabel,
                              style: const TextStyle(
                                  color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w700))
                        else if (canRate) ...[
                          Text(l.didItWorkOutPrompt,
                              style: TextStyle(color: c.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Row(children: [
                            _OutcomeChip(label: l.outcomeYesShort, color: AppColors.live, onTap: () => _setOutcome('matched')),
                            const SizedBox(width: 6),
                            _OutcomeChip(label: l.outcomeOpenShort, color: AppColors.accent, onTap: () => _setOutcome('open')),
                            const SizedBox(width: 6),
                            _OutcomeChip(label: l.outcomeNoShort, color: c.textSecondary, onTap: () => _setOutcome('no_deal')),
                          ]),
                        ] else if (canChat)
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: OutlinedButton.icon(
                              onPressed: () => _openChat(r),
                              icon: const Icon(Icons.forum_outlined, size: 14),
                              label: Text(l.sendMessageButton,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
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
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutcomeChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 28,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.6)),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
