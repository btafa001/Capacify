import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/capacity_provider.dart';
import '../services/company_provider.dart';
import '../../features/company/screens/company_detail_screen.dart';
import '../../features/onboarding/company_gate.dart';
import '../../features/opportunities/screens/capacity_detail_screen.dart';

/// Renders the normal app underneath, then opens the shared target on top of
/// it once resolved.
///
/// This is the shape the `?capacity=<id>` handler in main.dart already had, and
/// it's kept for a reason: a shared link that lands on a bare detail page is a
/// dead end — no navigation, and a back button with nothing to pop on a cold
/// load. Landing on the real app with the post/company opened over it means the
/// visitor can close it and keep browsing, signed in or not.
///
/// A target that no longer exists (deleted post, bad link) degrades to just the
/// app rather than an error page.
class DeepLinkPage extends ConsumerStatefulWidget {
  const DeepLinkPage({super.key, this.capacityId, this.companyId});

  final String? capacityId;
  final String? companyId;

  @override
  ConsumerState<DeepLinkPage> createState() => _DeepLinkPageState();
}

class _DeepLinkPageState extends ConsumerState<DeepLinkPage> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    final capacityId = widget.capacityId;
    final companyId = widget.companyId;

    if (capacityId != null && capacityId.isNotEmpty) {
      final capacity =
          await ref.read(capacityServiceProvider).getCapacityById(capacityId);
      if (!mounted || capacity == null) return;
      showCapacityDetailDialog(context, capacity);
      return;
    }

    if (companyId != null && companyId.isNotEmpty) {
      final company = await ref
          .read(companyServiceProvider)
          .getCompanyStream(companyId)
          .first;
      if (!mounted || company == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CompanyDetailScreen(company: company)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const CompanyGate();
}
