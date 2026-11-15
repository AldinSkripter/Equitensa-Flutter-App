import 'dart:convert';
import 'dart:typed_data';

import '../domain/models.dart';
import 'api_client.dart';

typedef Mutation<T> = ({FinanceState state, T result});

/// The single seam between UI and the shared Equitensa backend.
/// The backend stays authoritative for totals, numbering, calculations and permissions.
class EquitensaRepository {
  EquitensaRepository(this.api);
  final ApiClient api;

  // ---- Authentication (development: web cookie session) ----

  Future<void> login(String email, String password, {String? code}) async {
    await api.postJson('/auth/login', {
      'email': email.trim(),
      'password': password,
      'code': ?((code ?? '').isEmpty ? null : code),
    });
  }

  Future<Company> register({
    required String companyName,
    required String email,
    required String password,
    required Country country,
  }) async {
    final j = await api.postJson('/auth/register', {
      'companyName': companyName.trim(),
      'email': email.trim(),
      'password': password,
      'country': country.code,
    });
    return Company.fromJson(Map<String, dynamic>.from(j['company'] as Map));
  }

  Future<void> startDemo(Country country) => api.postJson('/demo', {'country': country.code});

  /// Local demo backends expose a one-tap synthetic company; production returns `database`.
  Future<bool> isDemoBackend() async {
    try {
      return (await api.getJson('/health'))['mode'] == 'demo';
    } on ApiException {
      return false;
    }
  }

  Future<Me> me() async => Me.fromJson(await api.getJson('/me'));

  Future<void> logout() async {
    try {
      await api.postJson('/auth/logout', {});
    } finally {
      api.clearSession();
    }
  }

  Future<void> resendVerification() => api.postJson('/auth/resend-verification', {});
  Future<void> forgotPassword(String email) => api.postJson('/auth/forgot-password', {'email': email.trim()});
  Future<void> verifyEmail(String token) => api.postJson('/auth/verify-email', {'token': token.trim()});
  Future<void> resetPassword(String token, String password) => api.postJson(
    '/auth/reset-password',
    {'token': token.trim(), 'password': password},
  );

  // ---- Finance ----

  Future<FinanceSnapshot> finance() async => FinanceSnapshot.fromJson(await api.getJson('/finance'));

  Mutation<T> _mutation<T>(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) result,
  ) => (
    state: FinanceState.fromJson(Map<String, dynamic>.from(j['state'] as Map)),
    result: result(Map<String, dynamic>.from((j['result'] ?? const {}) as Map)),
  );

  Map<String, dynamic> _contactBody(int revision, Map<String, dynamic> f) => {
    'revision': revision,
    ...f,
  };

  Future<Mutation<Contact>> createContact(
    int revision,
    Map<String, dynamic> fields,
  ) async => _mutation(
    await api.postJson('/finance/contacts', _contactBody(revision, fields)),
    Contact.fromJson,
  );

  Future<Mutation<Contact>> updateContact(
    String id,
    int revision,
    Map<String, dynamic> fields,
  ) async => _mutation(
    await api.postJson('/finance/contacts/$id', _contactBody(revision, fields)),
    Contact.fromJson,
  );

  /// Server-side calculation; revision is not consumed.
  Future<FinDoc> preview(Map<String, dynamic> draft) async {
    final j = await api.postJson('/finance/preview', draft);
    return FinDoc.fromJson(Map<String, dynamic>.from(j['document'] as Map));
  }

  Future<Mutation<FinDoc>> createDocument(
    int revision,
    Map<String, dynamic> draft,
  ) async => _mutation(
    await api.postJson('/finance/documents', {'revision': revision, ...draft}),
    FinDoc.fromJson,
  );

  Future<Mutation<FinDoc>> editDocument(
    String id,
    int revision,
    Map<String, dynamic> draft,
  ) async => _mutation(
    await api.postJson('/finance/documents/$id/edit', {
      'revision': revision,
      ...draft,
    }),
    FinDoc.fromJson,
  );

  Future<Mutation<FinDoc>> duplicate(String id, int revision) async => _mutation(
    await api.postJson('/finance/documents/$id/duplicate', {
      'revision': revision,
    }),
    FinDoc.fromJson,
  );

  Future<Mutation<FinDoc>> convertOffer(String id, int revision) async => _mutation(
    await api.postJson('/finance/documents/$id/convert', {
      'revision': revision,
    }),
    FinDoc.fromJson,
  );

  Future<IssueCheck> issueCheck(
    String id, {
    String? format,
  }) async => IssueCheck.fromJson(
    await api.getJson(
      '/finance/documents/$id/issue-check${format == null ? '' : '?format=$format'}',
    ),
  );

  /// A new [requestKey] must only be created once per user intent; reuse it for retries.
  Future<Mutation<FinDoc>> issue(
    String id, {
    required int revision,
    required String requestKey,
    String? format,
  }) async => _mutation(
    await api.postJson('/finance/documents/$id/issue', {
      'revision': revision,
      'confirm': true,
      'taxScopeConfirmed': true,
      'requestKey': requestKey,
      'format': ?format,
    }),
    FinDoc.fromJson,
  );

  Future<Mutation<FinDoc>> recordPayment(
    String id, {
    required int revision,
    required String amount,
    required String paidOn,
    String reference = '',
  }) async => _mutation(
    await api.postJson('/finance/documents/$id/payment', {
      'revision': revision,
      'amount': amount,
      'paidOn': paidOn,
      'reference': reference,
    }),
    FinDoc.fromJson,
  );

  Future<Uint8List> documentPdf(String id) => api.getBytes('/finance/documents/$id/pdf');

  Future<Mutation<Expense>> createExpense(
    int revision,
    Map<String, dynamic> fields,
  ) async => _mutation(
    await api.postJson('/finance/expenses', {'revision': revision, ...fields}),
    Expense.fromJson,
  );

  Future<Receipt> scanReceipt(String filename, Uint8List bytes) async => Receipt.fromJson(
    await api.postJson('/finance/receipt-scan', {
      'filename': filename,
      'data': base64Encode(bytes),
    }),
  );

  Future<Mutation<Expense>> importReceipt({
    required int revision,
    required String filename,
    required Uint8List bytes,
    required Map<String, dynamic> fields,
  }) async => _mutation(
    await api.postJson('/finance/receipt-import', {
      'revision': revision,
      'reviewed': true,
      'attachment': {'filename': filename, 'data': base64Encode(bytes)},
      ...fields,
    }),
    Expense.fromJson,
  );

  Future<Mutation<Map<String, dynamic>>> saveProfile(
    int revision,
    Map<String, dynamic> body,
  ) async => _mutation(
    await api.postJson('/finance/settings', {'revision': revision, ...body}),
    (r) => r,
  );

  Future<Map<String, dynamic>> quote(
    String plan,
    int paidSeats,
    String interval,
  ) => api.postJson('/finance/quote', {
    'plan': plan,
    'paidSeats': paidSeats,
    'interval': interval,
  });

  Future<Mutation<Map<String, dynamic>>> demoSubscription(
    String plan,
    int paidSeats,
    String interval,
  ) async => _mutation(
    await api.postJson('/finance/demo-subscription', {
      'plan': plan,
      'paidSeats': paidSeats,
      'interval': interval,
      'accepted': true,
    }),
    (r) => r,
  );

  // ---- Pay ----

  Future<PayAnalysis> payAnalysis(int year) async => PayAnalysis.fromJson(await api.getJson('/analysis?year=$year'));

  Future<PayReadiness> payReadiness(int year) async => PayReadiness.fromJson(await api.getJson('/workflow?year=$year'));
}
