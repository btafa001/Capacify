import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'credit_service.dart';
import '../models/credit_wallet_model.dart';

final creditServiceProvider = Provider<CreditService>((ref) => CreditService());

/// Live Vermittlung balance for a company (drives the sidebar + modal counters).
/// Note: this reflects the raw doc; call CreditService.ensureWallet() on entry
/// to apply the lazy monthly reset before reading.
final walletProvider =
    StreamProvider.family<CreditWalletModel?, String>((ref, companyId) {
  return ref.watch(creditServiceProvider).walletStream(companyId);
});
