@TestOn('vm')
library;

import 'dart:io';

import 'package:equitensa/data/api_client.dart';
import 'package:equitensa/data/repository.dart';
import 'package:equitensa/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the real repository against the local Equitensa demo backend (http://localhost:3000).
/// Skipped automatically when the backend is not running.
Future<bool> _backendUp() async {
  try {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final r = await (await c.getUrl(
      Uri.parse('http://localhost:3000/api/health'),
    )).close();
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  late bool up;

  setUpAll(() async {
    HttpOverrides.global = null; // flutter_test blocks real sockets by default
    up = await _backendUp();
  });

  test('demo login, contact, draft, server calculation, PDF', () async {
    if (!up) {
      markTestSkipped('backend not running on localhost:3000');
      return;
    }
    final repo = EquitensaRepository(
      ApiClient(baseUrl: 'http://localhost:3000'),
    );
    await repo.startDemo(Country.at);
    final me = await repo.me();
    expect(me.company.country, Country.at);
    expect(me.emailVerified, isTrue);

    var snap = await repo.finance();
    final contact = await repo.createContact(snap.state.revision, {
      'name': 'Live Test GmbH',
      'address': 'Testgasse 1',
      'postalCode': '1010',
      'city': 'Wien',
      'country': 'AT',
      'business': true,
      'publicBody': false,
      'vatId': 'ATU12345678',
      'email': 'live@example.com',
    });

    final draft = {
      'kind': 'invoice',
      'contactId': contact.result.id,
      'issueDate': '2026-11-15',
      'serviceDate': '2026-11-15',
      'dueDate': '2026-11-29',
      'note': 'live test',
      'lines': [
        {
          'description': 'Consulting',
          'quantity': '1',
          'unit': 'h',
          'unitPrice': '125.00',
          'rate': '20',
          'discountPercent': '0',
        },
      ],
    };
    final preview = await repo.preview(draft);
    expect(
      (preview.netCents, preview.taxCents, preview.grossCents),
      (12500, 2500, 15000),
    );

    final saved = await repo.createDocument(contact.state.revision, draft);
    expect(saved.result.isDraft, isTrue);
    expect(saved.state.revision, greaterThan(contact.state.revision));

    final pdf = await repo.documentPdf(saved.result.id);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');

    // A stale revision must be reported as a version conflict, never applied silently.
    await expectLater(
      repo.createDocument(contact.state.revision, draft),
      throwsA(
        isA<ApiException>().having((e) => e.isConflict, 'isConflict', isTrue),
      ),
    );

    final analysis = await repo.payAnalysis(2026);
    expect(analysis.count, greaterThan(0));
    final workflow = await repo.payReadiness(2026);
    expect(workflow.percent, inInclusiveRange(0, 100));
    expect(workflow.checks, isNotEmpty);

    // Re-fetch after each mutation: the same server state is used by the web.
    final edited = await repo.editDocument(saved.result.id, saved.state.revision, {
      ...draft,
      'note': 'Updated in Flutter',
    });
    final duplicated = await repo.duplicate(edited.result.id, edited.state.revision);
    expect(duplicated.result.id, isNot(edited.result.id));
    expect(duplicated.result.isDraft, isTrue);
    final expense = await repo.createExpense(duplicated.state.revision, {
      'supplier': 'Test Supplier',
      'reference': 'TEST-1',
      'incurredOn': '2026-11-15',
      'amount': '24.90',
      'category': 'office',
      'note': 'Integration test',
    });
    expect(expense.result.amountCents, 2490);
    final profile = await repo.saveProfile(expense.state.revision, {
      ...expense.state.profile.raw,
      'country': 'AT',
      'confirmCountry': true,
      'name': 'Flutter Integration GmbH',
    });
    final refreshed = await repo.finance();
    expect(refreshed.state.revision, profile.state.revision);
    expect(refreshed.state.profile.name, 'Flutter Integration GmbH');
    expect(refreshed.state.expenses.any((item) => item.id == expense.result.id), isTrue);
    expect(refreshed.state.documents.firstWhere((item) => item.id == edited.result.id).note, 'Updated in Flutter');
    await repo.logout();
  });

  test('registration and fresh login use the shared web account', () async {
    if (!up) {
      markTestSkipped('backend not running on localhost:3000');
      return;
    }
    final health = await ApiClient(baseUrl: 'http://localhost:3000', persist: false).getJson('/health');
    if (health['mode'] != 'demo') {
      markTestSkipped('account creation is restricted to the local demo backend');
      return;
    }
    final email = 'flutter-auth-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
    const password = 'Flutter-auth-check-2026!';
    final registration = EquitensaRepository(ApiClient(baseUrl: 'http://localhost:3000', persist: false));
    final company = await registration.register(
      companyName: 'Flutter Auth Test',
      email: email,
      password: password,
      country: Country.de,
    );
    final registered = await registration.me();
    expect(registered.company.id, company.id);
    expect(registered.email, email);
    expect(registered.emailVerified, isFalse);
    await registration.logout();
    final login = EquitensaRepository(ApiClient(baseUrl: 'http://localhost:3000', persist: false));
    await login.login(email, password);
    final signedIn = await login.me();
    expect(signedIn.company.id, company.id);
    expect(signedIn.email, email);
    await login.logout();
    await expectLater(login.me(), throwsA(isA<ApiException>().having((e) => e.isAuth, 'isAuth', isTrue)));
  });

  test('wrong credentials are reported as INVALID_LOGIN', () async {
    if (!up) {
      markTestSkipped('backend not running on localhost:3000');
      return;
    }
    final repo = EquitensaRepository(
      ApiClient(baseUrl: 'http://localhost:3000'),
    );
    await expectLater(
      repo.login('nobody@example.com', 'definitely-wrong'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'INVALID_LOGIN'),
      ),
    );
  });
}
