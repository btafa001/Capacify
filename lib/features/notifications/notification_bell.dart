import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/contact_request_model.dart';
import '../../core/models/chat_model.dart';
import '../../core/models/capacity_model.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/contact_request_provider.dart';
import '../../core/services/chat_provider.dart';
import '../../core/services/company_provider.dart';
import '../../core/services/capacity_provider.dart';
import '../../core/services/saved_search_service.dart';
import '../../core/services/notification_provider.dart';
import '../messaging/screens/chat_screen.dart';
import '../opportunities/screens/capacity_detail_screen.dart';
import '../company/screens/company_detail_screen.dart';
import '../admin/screens/admin_screen.dart';

/// Last time the user opened the notification center, in ms since epoch, kept
/// in localStorage (per-device — same JS-interop pattern as theme/consent).
/// A Vermittlung created after this counts as "new" for the badge. Message
/// unreads come from the authoritative server-tracked per-chat counter.
const _seenKey = 'notif_seen_at';

class NotifSeenNotifier extends Notifier<int> {
  @override
  int build() {
    try {
      return int.tryParse(web.window.localStorage.getItem(_seenKey) ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void markSeenNow() {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = now;
    try {
      web.window.localStorage.setItem(_seenKey, now.toString());
    } catch (_) {}
  }
}

final notifSeenProvider = NotifierProvider<NotifSeenNotifier, int>(NotifSeenNotifier.new);

/// Recent capacities that match what this user cares about — the in-app half of
/// "trade / district alerts" (Objective 2, daily habit). Computed entirely on
/// the client from streams the app already holds: the public feed, the user's
/// saved searches (their explicit intent) and their own posts (to exclude). No
/// backend, no new collection — so it works within the current no-email
/// constraint and greets the user with relevant matches the moment they open
/// the app. Falls back to the company's own trades when no search has been
/// saved yet, so the loop works from day one.
///
/// This is NOT filtered by last-seen: the center always shows the recent slice
/// (a 7-day window so it never goes stale); the *badge* separately counts only
/// the ones newer than last-seen (see [NotificationBell]).
const _matchWindow = Duration(days: 7);

final matchAlertsProvider =
    Provider.family<List<CapacityModel>, String>((ref, uid) {
  final caps = ref.watch(capacitiesProvider).valueOrNull ?? const [];
  final searches = ref.watch(mySavedSearchesProvider).valueOrNull ?? const [];
  final myCompany = ref.watch(myCompanyProvider(uid)).valueOrNull;
  final myPostIds =
      (ref.watch(myCapacitiesProvider(uid)).valueOrNull ?? const [])
          .map((p) => p.id)
          .toSet();
  final fallbackTrades = myCompany?.trades ?? const <String>[];
  final cutoff = DateTime.now().subtract(_matchWindow);

  bool matches(CapacityModel cap) {
    if (searches.isEmpty) {
      // No saved search yet — use the company's own trades as intent.
      return fallbackTrades.contains(cap.trade);
    }
    for (final s in searches) {
      final tradeOk = s.trades.isEmpty || s.trades.contains(cap.trade);
      final typeOk = s.type == 'all' ||
          (s.type == 'offer' && cap.type == CapacityType.offer) ||
          (s.type == 'need' && cap.type == CapacityType.need);
      final crewOk = cap.workerCount >= s.crewMin;
      if (tradeOk && typeOk && crewOk) return true;
    }
    return false;
  }

  final list = caps
      .where((cap) =>
          cap.isActiveInFeed &&
          !myPostIds.contains(cap.id) &&
          (cap.createdAt?.isAfter(cutoff) ?? false) &&
          matches(cap))
      .toList()
    ..sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return list;
});

/// Top-bar bell with a combined unread badge — this is the in-app half of the
/// "close the loop" fix: a poster who's been unlocked, or who has unread chat
/// messages, sees it the moment they open the app instead of digging through
/// tabs. (Real email/push is the remaining, separately-gated half.)
class NotificationBell extends ConsumerWidget {
  final String uid;
  const NotificationBell({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final seenAt = ref.watch(notifSeenProvider);
    final vermittlungen = ref.watch(receivedRequestsProvider(uid)).valueOrNull ?? [];
    final unreadMessages = ref.watch(totalUnreadProvider(uid));

    final newVermittlungen = vermittlungen
        .where((r) => (r.createdAt?.millisecondsSinceEpoch ?? 0) > seenAt)
        .length;
    // Only matches newer than last-seen count toward the badge; the center
    // itself shows the full recent window.
    final newMatches = ref
        .watch(matchAlertsProvider(uid))
        .where((cap) => (cap.createdAt?.millisecondsSinceEpoch ?? 0) > seenAt)
        .length;
    // Real, persisted, cross-device admin-only events (verification/flag/
    // rating) — naturally 0 for non-admins, since only admin uids ever
    // receive those notification types.
    final unreadAdminNotifs = ref.watch(unreadAdminNotificationsProvider(uid));
    final count = newVermittlungen + unreadMessages + newMatches + unreadAdminNotifs.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: AppLocalizations.of(context).notificationsTitle,
          icon: Icon(Icons.notifications_none_rounded, color: c.textSecondary, size: 24),
          onPressed: () {
            _openCenter(context, ref);
            ref.read(notifSeenProvider.notifier).markSeenNow();
            ref
                .read(notificationServiceProvider)
                .markAllRead(ref.read(unreadAdminNotificationsProvider(uid)));
          },
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: c.surface, width: 1.5),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openCenter(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => _NotificationCenter(uid: uid),
    );
  }
}

class _NotificationCenter extends ConsumerWidget {
  final String uid;
  const _NotificationCenter({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final vermittlungen = ref.watch(receivedRequestsProvider(uid)).valueOrNull ?? [];
    final chats = ref.watch(myChatsProvider(uid)).valueOrNull ?? [];
    final unreadChats = chats.where((ch) => ch.unreadFor(uid) > 0).toList();
    final matches = ref.watch(matchAlertsProvider(uid));
    final adminNotifs = (ref.watch(myNotificationsProvider(uid)).valueOrNull ?? [])
        .where((n) => n.isAdminEvent)
        .toList();

    final recentVermittlungen = [...vermittlungen]
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    final isEmpty = recentVermittlungen.isEmpty &&
        unreadChats.isEmpty &&
        matches.isEmpty &&
        adminNotifs.isEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(l.notificationsTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary)),
          ),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Text(l.notificationsEmpty,
                  style: TextStyle(color: c.textTertiary, fontSize: 14, height: 1.5)),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // Match alerts first — the freshest reason to have opened.
                  if (matches.isNotEmpty)
                    _SectionLabel(label: l.notificationsMatches),
                  ...matches.take(8).map((cap) => _MatchTile(capacity: cap)),
                  if (recentVermittlungen.isNotEmpty)
                    _SectionLabel(label: l.notificationsVermittlungen),
                  ...recentVermittlungen.take(8).map((r) => _VermittlungTile(request: r, uid: uid)),
                  if (unreadChats.isNotEmpty) _SectionLabel(label: l.notificationsMessages),
                  ...unreadChats.take(8).map((ch) => _ChatTile(chat: ch, uid: uid)),
                  if (adminNotifs.isNotEmpty) _SectionLabel(label: l.notificationsAdminEvents),
                  ...adminNotifs.take(8).map((n) => _AdminNotifTile(notification: n)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w900, color: c.textTertiary, letterSpacing: 0.6)),
    );
  }
}

/// A new capacity that matches the user's saved search / trades. Tapping opens
/// the anonymized detail (where they can send a free message).
class _MatchTile extends StatelessWidget {
  final CapacityModel capacity;
  const _MatchTile({required this.capacity});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isOffer = capacity.type == CapacityType.offer;
    final accent = isOffer ? AppColors.offerColor : AppColors.needColor;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(isOffer ? Icons.bolt_outlined : Icons.search,
            size: 18, color: accent),
      ),
      title: Text(capacity.autoTitle(l),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text(capacity.autoSubtitle(l),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textTertiary, fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        showCapacityDetailDialog(context, capacity);
      },
    );
  }
}

class _VermittlungTile extends ConsumerWidget {
  final ContactRequestModel request;
  final String uid;
  const _VermittlungTile({required this.request, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final r = request;
    final company = ref.watch(companyByIdProvider(r.requesterCompanyId)).valueOrNull;
    final name = (company?.name.isNotEmpty ?? false) ? company!.name : r.requesterCompanyName;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.live.withOpacity(0.12), shape: BoxShape.circle),
        child: const Icon(Icons.lock_open_outlined, size: 18, color: AppColors.live),
      ),
      title: Text(l.notificationUnlockedBy(name),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text('${l.tradeName(r.trade)} · ${r.workerCount} ${l.persons}',
          style: TextStyle(color: c.textTertiary, fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: r.id,
              myCompanyId: uid,
              otherCompanyId: r.requesterCompanyId,
              otherCompanyName: name,
              postId: r.postId,
            ),
          ),
        );
      },
    );
  }
}

class _ChatTile extends ConsumerWidget {
  final ChatModel chat;
  final String uid;
  const _ChatTile({required this.chat, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final otherId = chat.otherParticipant(uid);
    final company = ref.watch(companyByIdProvider(otherId)).valueOrNull;
    final name = (company?.name.isNotEmpty ?? false) ? company!.name : l.chatFallbackTitle;
    final unread = chat.unreadFor(uid);
    return ListTile(
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: AppColors.primary.withOpacity(0.15),
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 15)),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
      subtitle: Text(chat.lastMessage.isEmpty ? l.notificationsMessages : chat.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textSecondary, fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
        child: Text('$unread',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chat.id,
              myCompanyId: uid,
              otherCompanyId: otherId,
              otherCompanyName: name,
              postId: chat.postId,
            ),
          ),
        );
      },
    );
  }
}

/// An admin-only event (verification submitted / content flagged / rating
/// pending) — only ever addressed to admin uids, so this tile never renders
/// for a regular user. Tapping opens the related company's profile; falls
/// back to the Admin screen when there's no company to show (an anonymous
/// flagged capacity) or the company hasn't loaded yet.
class _AdminNotifTile extends ConsumerWidget {
  final NotificationModel notification;
  const _AdminNotifTile({required this.notification});

  (IconData, String) _iconAndTitle(AppLocalizations l) {
    final n = notification;
    switch (n.type) {
      case 'verification_submitted':
        return (Icons.verified_outlined, l.notificationVerificationSubmitted(n.companyName));
      case 'content_flagged':
        return (
          Icons.flag_outlined,
          n.contentType == 'capacity'
              ? l.notificationContentFlaggedCapacity
              : l.notificationContentFlaggedCompany(n.companyName),
        );
      case 'rating_submitted':
        return (Icons.star_outline, l.notificationRatingSubmitted(n.companyName));
      default:
        return (Icons.notifications_none_rounded, n.companyName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final n = notification;
    final company =
        n.companyId.isEmpty ? null : ref.watch(companyByIdProvider(n.companyId)).valueOrNull;
    final (icon, title) = _iconAndTitle(l);
    final date = n.createdAt;
    final dateStr = date != null ? '${date.day}.${date.month}.${date.year}' : '';

    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppColors.accent),
      ),
      title: Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: dateStr.isEmpty
          ? null
          : Text(l.sinceDateLabel(dateStr),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        if (company != null) {
          showCompanyDetailDialog(context, company);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
        }
      },
    );
  }
}
