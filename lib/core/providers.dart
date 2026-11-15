import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_repository.dart';
import '../domain/models.dart';
import '../domain/repository.dart';

class DemoFlagsNotifier extends Notifier<DemoFlags> {
  @override
  DemoFlags build() => const DemoFlags();
  void setOffline(bool v) => state = state.copyWith(offline: v);
  void setConflict(bool v) => state = state.copyWith(conflict: v);
}

final demoFlagsProvider = NotifierProvider<DemoFlagsNotifier, DemoFlags>(
  DemoFlagsNotifier.new,
);

final repositoryProvider = Provider<EquitensaRepository>(
  (ref) => MockRepository(() => ref.read(demoFlagsProvider)),
);

class SessionNotifier extends Notifier<Company?> {
  @override
  Company? build() => null;

  Future<void> signIn(String companyId) async {
    final c = await ref.read(repositoryProvider).selectCompany(companyId);
    state = c;
  }

  Future<void> setPlan(FinancePlan plan) async {
    await ref.read(repositoryProvider).setDemoPlan(plan);
    state = state?.copyWith(plan: plan);
    refreshFinance(ref);
  }

  void signOut() {
    // Clears everything that belongs to the previous company.
    state = null;
    ref.invalidate(financeOverviewProvider);
    ref.invalidate(contactsProvider);
    ref.invalidate(invoicesProvider);
    ref.invalidate(expensesProvider);
    ref.invalidate(payOverviewProvider);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Company?>(
  SessionNotifier.new,
);

class LanguageOverrideNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? lang) => state = lang;
}

/// Explicit UI-language choice. Never changes the company's country rules.
final languageOverrideProvider =
    NotifierProvider<LanguageOverrideNotifier, String?>(
      LanguageOverrideNotifier.new,
    );

final languageProvider = Provider<String>((ref) {
  final override = ref.watch(languageOverrideProvider);
  if (override != null) return override;
  return ref.watch(sessionProvider.select((c) => c?.country.defaultLanguage)) ??
      'de';
});

final companiesProvider = FutureProvider.autoDispose<List<Company>>(
  (ref) => ref.watch(repositoryProvider).companies(),
);

final financeOverviewProvider = FutureProvider.autoDispose<FinanceOverview>(
  (ref) => ref.watch(repositoryProvider).financeOverview(),
);
final contactsProvider = FutureProvider.autoDispose<List<Contact>>(
  (ref) => ref.watch(repositoryProvider).contacts(),
);
final invoicesProvider = FutureProvider.autoDispose<List<Invoice>>(
  (ref) => ref.watch(repositoryProvider).invoices(),
);
final expensesProvider = FutureProvider.autoDispose<List<Expense>>(
  (ref) => ref.watch(repositoryProvider).expenses(),
);
final payOverviewProvider = FutureProvider.autoDispose<PayOverview>(
  (ref) => ref.watch(repositoryProvider).payOverview(),
);

void refreshFinance(Ref ref) {
  ref.invalidate(financeOverviewProvider);
  ref.invalidate(contactsProvider);
  ref.invalidate(invoicesProvider);
  ref.invalidate(expensesProvider);
}

extension WidgetRefRefresh on WidgetRef {
  void refreshFinanceData() {
    invalidate(financeOverviewProvider);
    invalidate(contactsProvider);
    invalidate(invoicesProvider);
    invalidate(expensesProvider);
  }

  Future<int> latestRevision() async {
    invalidate(financeOverviewProvider);
    return (await read(financeOverviewProvider.future)).revision;
  }
}
