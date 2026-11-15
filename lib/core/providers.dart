import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/repository.dart';
import '../domain/models.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final repositoryProvider = Provider<EquitensaRepository>(
  (ref) => EquitensaRepository(ref.watch(apiClientProvider)),
);

final workspaceBrandProvider = FutureProvider<Map<String, dynamic>>(
  (ref) async =>
      Map<String, dynamic>.from((await ref.watch(apiClientProvider).getJson('/company/brand'))['brand'] as Map? ?? {}),
);

/// Re-read shared web data without replaying mutations or replacing form input.
Future<void> refreshWorkspace(WidgetRef ref) async {
  if (ref.read(sessionProvider).value == null) return;
  await ref.read(sessionProvider.notifier).refresh();
  ref.invalidate(financeProvider);
  ref.invalidate(payAnalysisProvider);
  ref.invalidate(payReadinessProvider);
  ref.invalidate(workspaceBrandProvider);
}

/// Authenticated user + company, or `null` when signed out. Restored from the cookie on start.
class SessionNotifier extends AsyncNotifier<Me?> {
  @override
  Future<Me?> build() async {
    final api = ref.read(apiClientProvider);
    api.onSessionLost = expire;
    await api.restore();
    try {
      return await ref.read(repositoryProvider).me();
    } on ApiException {
      return null;
    }
  }

  EquitensaRepository get _repo => ref.read(repositoryProvider);

  Future<void> login(String email, String password, {String? code}) async {
    await _repo.login(email, password, code: code);
    state = AsyncData(await _repo.me());
    _resetData();
  }

  Future<void> register({
    required String companyName,
    required String email,
    required String password,
    required Country country,
  }) async {
    await _repo.register(
      companyName: companyName,
      email: email,
      password: password,
      country: country,
    );
    state = AsyncData(await _repo.me());
    _resetData();
  }

  Future<void> startDemo(Country country) async {
    await _repo.startDemo(country);
    state = AsyncData(await _repo.me());
    _resetData();
  }

  /// Re-reads the account, e.g. after the user confirmed the email link in their mail app.
  Future<Me?> refresh() async {
    final me = await _repo.me();
    state = AsyncData(me);
    return me;
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } on ApiException {
      // The local session is dropped either way.
    }
    expire();
  }

  void expire() {
    ref.read(apiClientProvider).clearSession();
    state = const AsyncData(null);
    _resetData();
    ref.read(languageOverrideProvider.notifier).set(null);
  }

  void _resetData() {
    ref.invalidate(workspaceBrandProvider);
    ref.invalidate(financeProvider);
    ref.invalidate(payAnalysisProvider);
    ref.invalidate(payReadinessProvider);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Me?>(
  SessionNotifier.new,
);

/// Explicit UI-language choice. Never changes the company's country rules.
class LanguageOverrideNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? lang) => state = lang;
}

final languageOverrideProvider = NotifierProvider<LanguageOverrideNotifier, String?>(
  LanguageOverrideNotifier.new,
);

/// Country picked on the auth screens before a company exists (language preview only).
class AuthCountryNotifier extends Notifier<Country> {
  @override
  Country build() => Country.de;
  void set(Country c) => state = c;
}

final authCountryProvider = NotifierProvider<AuthCountryNotifier, Country>(
  AuthCountryNotifier.new,
);

final countryProvider = Provider<Country>((ref) {
  final me = ref.watch(sessionProvider).value;
  return me?.company.country ?? ref.watch(authCountryProvider);
});

final languageProvider = Provider<String>((ref) {
  final override = ref.watch(languageOverrideProvider);
  if (override != null) return override;
  return ref.watch(countryProvider).language;
});

/// Whole Finance state of the company. Mutations replace it with the state the server returns.
class FinanceNotifier extends AsyncNotifier<FinanceSnapshot> {
  @override
  Future<FinanceSnapshot> build() => _load();

  Future<FinanceSnapshot> _load() async {
    final repo = ref.read(repositoryProvider);
    final snapshot = await repo.finance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final due = (snapshot.state.raw['recurring'] as List? ?? []).whereType<Map>().any(
      (r) => r['autoOnOpen'] == true && r['paused'] != true && '${r['nextDate'] ?? '9999'}'.compareTo(today) <= 0,
    );
    if (!due) return snapshot;
    try {
      final result = await repo.financeAction('recurring/run', snapshot.state.revision, {'autoOnly': true});
      return snapshot.withState(result.state);
    } on ApiException catch (error) {
      if (error.isConflict) return repo.finance();
      rethrow;
    }
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(
      _load,
    );
  }

  void apply(FinanceState s) {
    final current = state.value;
    if (current != null) state = AsyncData(current.withState(s));
  }

  /// Runs a mutation with the latest known revision and adopts the returned state.
  Future<T> mutate<T>(Future<Mutation<T>> Function(int revision) run) async {
    final revision = state.value?.state.revision ?? (await future).state.revision;
    final m = await run(revision);
    apply(m.state);
    return m.result;
  }
}

final financeProvider = AsyncNotifierProvider<FinanceNotifier, FinanceSnapshot>(
  FinanceNotifier.new,
);

class PayYearController extends Notifier<int> {
  @override
  int build() => DateTime.now().year;
  void set(int year) => state = year;
}

final payYearProvider = NotifierProvider<PayYearController, int>(PayYearController.new);

final payAnalysisProvider = FutureProvider<PayAnalysis>(
  (ref) => ref.watch(repositoryProvider).payAnalysis(ref.watch(payYearProvider)),
);

final payReadinessProvider = FutureProvider<PayReadiness>(
  (ref) => ref.watch(repositoryProvider).payReadiness(ref.watch(payYearProvider)),
);
