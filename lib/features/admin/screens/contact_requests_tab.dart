import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/contact_request_model.dart';
import '../../../core/models/capacity_owner_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/contact_request_provider.dart';

/// Founder queue of all contact requests. Admins can read the locked
/// capacityOwners sidecar, so each card resolves and shows the poster, lets
/// the founder broker/grant, and records a rough value estimate.
class ContactRequestsTab extends ConsumerWidget {
  const ContactRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final async = ref.watch(allContactRequestsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text(l.errorWithMessage(e), style: const TextStyle(color: AppColors.error))),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(child: Text(l.noContactRequestsText, style: TextStyle(color: c.textTertiary, fontSize: 13)));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
          itemCount: requests.length,
          itemBuilder: (_, i) => _RequestCard(request: requests[i]),
        );
      },
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final ContactRequestModel request;
  const _RequestCard({required this.request});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  CapacityOwnerModel? _owner;
  bool _loadingOwner = true;
  int _ownerPostCount = 0;

  @override
  void initState() {
    super.initState();
    _resolveOwner();
  }

  Future<void> _resolveOwner() async {
    final service = ref.read(capacityServiceProvider);
    final owner = await service.getCapacityOwner(widget.request.postId);
    // Lightweight "repeat poster" signal for the founder.
    final count = owner != null ? await service.countOwnerPosts(owner.posterCompanyId) : 0;
    if (mounted) {
      setState(() {
        _owner = owner;
        _ownerPostCount = count;
        _loadingOwner = false;
      });
    }
  }

  // pending_review → granted: founder approves a screened request, which grants
  // the reveal and debits one of the requester's Vermittlungen.
  Future<void> _approveGrant() async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(contactRequestServiceProvider).approveGrant(
            requestId: widget.request.id,
            requesterCompanyId: widget.request.requesterCompanyId,
            posterCompanyId: _owner?.posterCompanyId,
          );
    } catch (e) {
      if (mounted) _snack(l.errorWithMessage(e), AppColors.error);
    }
  }

  Future<void> _reject() async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(contactRequestServiceProvider).reject(widget.request.id);
    } catch (e) {
      if (mounted) _snack(l.errorWithMessage(e), AppColors.error);
    }
  }


  void _snack(String m, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final r = widget.request;
    final posterName = _loadingOwner
        ? '…'
        : (_owner?.companyName.isNotEmpty == true ? _owner!.companyName : l.posterUnresolvedLabel);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Requester → Poster
          Row(children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: r.requesterCompanyName.isEmpty ? r.requesterCompanyId : r.requesterCompanyName,
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                TextSpan(text: '  →  ', style: TextStyle(color: c.textTertiary)),
                TextSpan(text: posterName,
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
              ])),
            ),
            _StatusChip(status: r.status),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text('${l.tradeName(r.trade)} · ${r.workerCount} ${l.persons}',
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ),
            if (!_loadingOwner && _ownerPostCount > 0)
              Text(l.postsFromCompany(_ownerPostCount),
                  style: TextStyle(color: c.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          if (r.requesterVerified) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.verified_outlined, size: 13, color: AppColors.live),
              const SizedBox(width: 4),
              Text(l.trustVerifiedCompany,
                  style: const TextStyle(color: AppColors.live, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ],
          if (r.message.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.requesterMessageLabel.toUpperCase(),
                    style: TextStyle(
                        fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: c.textTertiary)),
                const SizedBox(height: 3),
                Text(r.message.trim(), style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4)),
              ]),
            ),
          ],
          if (r.outcome != null) ...[
            const SizedBox(height: 4),
            Text('${l.outcomeFieldLabel}: ${r.outcome == 'matched' ? l.outcomeMatchedLabel : l.outcomeNoDealLabel}',
                style: TextStyle(color: c.textTertiary, fontSize: 12)),
          ],

          const SizedBox(height: 12),

          // Safety-net actions — posters accept directly now, but the founder
          // can still force-accept or reject a pending message from here.
          if (r.status == 'pending' || r.status == 'pending_review')
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _reject,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                child: Text(l.rejectLabel),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: _approveGrant,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.live, foregroundColor: Colors.white),
                child: Text(l.approveGrantButton),
              )),
            ]),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = status == 'granted'
        ? AppColors.live
        : status == 'declined'
            ? AppColors.error
            : (status == 'pending' || status == 'pending_review')
                ? AppColors.accent
                : status == 'closed'
                    ? AppColors.of(context).textTertiary
                    : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(l.requestStatusLabel(status),
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
    );
  }
}

