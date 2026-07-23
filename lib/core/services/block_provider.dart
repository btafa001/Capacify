import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'block_service.dart';
import 'auth_provider.dart';

final blockServiceProvider = Provider<BlockService>((ref) => BlockService());

/// Whether the signed-in user's own company has blocked [blockedCompanyId].
final isBlockedByMeProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, blockedCompanyId) {
  final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (myUid == null || myUid == blockedCompanyId) return Stream.value(false);
  return ref.read(blockServiceProvider).isBlockedByMe(
        blockerCompanyId: myUid,
        blockedCompanyId: blockedCompanyId,
      );
});

/// Every company id the signed-in user's own company has blocked — for
/// filtering directory/feed listings client-side.
final myBlockedCompanyIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (myUid == null) return Stream.value(<String>{});
  return ref.read(blockServiceProvider).blockedCompanyIds(myUid);
});
