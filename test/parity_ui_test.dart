import 'dart:convert';

import 'package:equitensa/app.dart';
import 'package:equitensa/core/appearance.dart';
import 'package:equitensa/core/providers.dart';
import 'package:equitensa/domain/contact_countries.dart';
import 'package:equitensa/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'app_test.dart' show boot;

typedef Data = Map<String, dynamic>;
Data financeState() => {
  'revision': 3,
  'country': 'DE',
  'countryConfirmed': true,
  'profile': {
    'name': 'Shared Company',
    'address': 'Street 1',
    'city': 'Berlin',
    'postalCode': '10115',
    'vatId': 'DE123456789',
    'iban': 'DE89370400440532013000',
    'accent': '#7451f8',
    'design': {
      'template': 'signature',
      'columns': ['description', 'total'],
    },
  },
  'contacts': [],
  'documents': [],
  'expenses': [
    {
      'id': 'e1',
      'supplier': 'Vendor',
      'reference': 'EXP1',
      'incurredOn': '2026-01-01',
      'amountCents': 2500,
      'category': 'office',
    },
  ],
  'products': [
    {
      'id': 'p1',
      'name': 'Consulting',
      'sku': 'P1',
      'unitPrice': '100.00',
      'rate': '19',
      'unit': 'h',
      'archived': false,
    },
  ],
  'recurring': [],
  'bankTransactions': [],
  'designs': [],
  'attachments': [],
  'events': [],
};
MockClient backend({Future<http.Response?> Function(http.Request)? intercept}) {
  var state = financeState();
  return MockClient((req) async {
    final intercepted = await intercept?.call(req);
    if (intercepted != null) return intercepted;
    http.Response json(Data v, [int status = 200]) =>
        http.Response(jsonEncode(v), status, headers: {'content-type': 'application/json'});
    final p = req.url.path;
    if (p == '/api/me') {
      return json({
        'company': {'id': 'co', 'name': 'Shared Company', 'country': 'DE'},
        'user': {'email': 'test@example.invalid', 'role': 'hr_manager', 'emailVerified': true, 'mfaEnabled': false},
        'demo': true,
      });
    }
    if (p == '/api/health') return json({'mode': 'demo'});
    if (p == '/api/company/brand') {
      return json({
        'brand': {'displayName': 'Shared Company', 'logo': ''},
      });
    }
    if (p == '/api/finance') return json({'state': state, 'plans': [], 'capabilities': {}, 'demo': true});
    if (p == '/api/finance/contacts' && req.method == 'POST') {
      final body = Map<String, dynamic>.from(jsonDecode(req.body) as Map);
      final c = {...body, 'id': 'new'};
      state = {
        ...state,
        'revision': 4,
        'contacts': [c],
      };
      return json({'state': state, 'result': c});
    }
    if (p == '/api/analysis') {
      return json({
        'year': 2026,
        'snapshot': {'id': 's1'},
        'analysis': {
          'count': 12,
          'groups': [
            {'category': 'Engineering', 'count': 12, 'male_count': 6, 'female_count': 6},
          ],
          'quartiles': [],
        },
      });
    }
    if (p == '/api/employer-context') {
      return json({
        'snapshotId': 's1',
        'categories': [
          {
            'category': 'Engineering',
            'titles': ['Engineer'],
          },
        ],
      });
    }
    if (p == '/api/workflow') {
      return json({
        'workflow': {
          'snapshotId': 's1',
          'profile': {'legalName': 'Shared Company', 'headcount': 12, 'payrollComplete': false},
        },
        'readiness': {'percent': 20, 'checks': [], 'missing': []},
      });
    }
    if (p == '/api/requests') return json({'requests': [], 'summary': {}});
    if (p == '/api/rights-notice') return json({'notice': null});
    if (p == '/api/pay-criteria') {
      return json({
        'document': {'ranges': {}, 'progression': ''},
        'suggestions': {
          'Engineering': {'min': 50000, 'max': 70000},
        },
      });
    }
    if (p == '/api/employer-controls') {
      return json({
        'document': {'snapshotId': 's1', 'records': {}},
        'snapshotId': 's1',
        'state': {'stale': false},
        'articles': [],
      });
    }
    if (p == '/api/national-report') {
      return json({
        'country': 'DE',
        'rule': {'id': 'DE', 'title': 'Nationaler Bericht', 'scope': 'National rules'},
        'document': null,
      });
    }
    if (p == '/api/payroll') return json({'version': 0, 'codes': [], 'errors': [], 'ready': false});
    if (p == '/api/integrations') {
      return json({
        'providers': [],
        'guides': [],
        'requiredData': {'de': [], 'sl': []},
        'push': {},
      });
    }
    if (p == '/api/integrations/keys') return json({'keys': []});
    if (p == '/api/integrations/batches' || p == '/api/import/history') return json({'batches': []});
    if (p == '/api/data-retention') return json({'policy': null, 'counts': {}, 'fingerprint': 'f1', 'held': false});
    if (p == '/api/data-retention/receipts') return json({'receipts': []});
    if (p == '/api/billing') {
      return json({
        'plans': [
          {'id': 'prepare', 'name': 'Prepare', 'monthly': 119, 'annual': 1428},
        ],
        'mode': 'sandbox',
        'order': null,
      });
    }
    if (p == '/api/finance/receivables') {
      return json({'outstandingCents': 0, 'overdueCents': 0, 'buckets': {}, 'rows': []});
    }
    if (p == '/api/reporting-plan') return json({'automaticSubmission': false});
    return json({'error': 'TEST_ROUTE_MISSING:$p'}, 404);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Inter');
    for (final weight in ['400Regular', '500Medium', '600SemiBold', '700Bold', '800ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter_$weight.ttf'));
    }
    await loader.load();
  });
  test('recipient countries preserve all 249 web ISO codes independently of issuer country', () {
    expect(contactCountries.length, 249);
    for (final code in ['BA', 'RS', 'HR', 'CH', 'GB', 'US', 'FR', 'JP']) {
      expect(contactCountries.containsKey(code), true);
      final c = Contact.fromJson({'country': code});
      expect(c.countryCode, code);
    }
  });
  testWidgets('every added Pay and Finance module renders in both appearances', (t) async {
    await boot(t, signedIn: true, client: backend());
    final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
    final routes = [
      '/pay/report',
      '/pay/import',
      '/pay/analysis',
      '/pay/rights',
      '/pay/criteria',
      '/pay/obligations',
      '/pay/national',
      '/pay/payroll',
      '/pay/integrations',
      '/pay/retention',
      '/pay/billing',
      '/pay/exports',
      '/finance/products',
      '/finance/bank',
      '/finance/recurring',
      '/finance/receivables',
      '/finance/exports',
      '/finance/designs',
      '/finance/style',
      '/finance/documents',
      '/finance/expense/e1',
      '/account/brand',
    ];
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(appearanceProvider.notifier).set(mode);
      for (final route in routes) {
        container.read(routerProvider).go(route);
        await t.pumpAndSettle();
        expect(find.textContaining('TEST_ROUTE_MISSING'), findsNothing, reason: route);
        expect(find.textContaining('ApiException'), findsNothing, reason: route);
        expect(t.takeException(), isNull, reason: '$mode $route');
      }
    }
  });
  testWidgets('contact country search saves Bosnia to the same Finance API', (t) async {
    Data? posted;
    await boot(
      t,
      signedIn: true,
      client: backend(
        intercept: (r) async {
          if (r.url.path == '/api/finance/contacts' && r.method == 'POST') {
            posted = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          }
          return null;
        },
      ),
    );
    final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
    container.read(routerProvider).go('/finance/contact');
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'Bosnian Customer');
    await t.scrollUntilVisible(find.textContaining('Deutschland'), 300, scrollable: find.byType(Scrollable).last);
    await t.tap(find.textContaining('Deutschland'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Bosnien');
    await t.pumpAndSettle();
    await t.tap(find.text('Bosnien und Herzegowina'));
    await t.pumpAndSettle();
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(posted?['country'], 'BA');
    expect(posted?['revision'], 3);
    expect(container.read(financeProvider).value!.state.contacts.single.countryCode, 'BA');
    expect(t.takeException(), isNull);
  });
  testWidgets('workflow conflict retains edits and submits the loaded snapshot', (t) async {
    Data? posted;
    await boot(
      t,
      signedIn: true,
      client: backend(
        intercept: (r) async {
          if (r.url.path == '/api/workflow' && r.method == 'POST') {
            posted = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
            return http.Response('{"error":"SNAPSHOT_CHANGED"}', 409, headers: {'content-type': 'application/json'});
          }
          return null;
        },
      ),
    );
    final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
    container.read(routerProvider).go('/pay/report');
    await t.pumpAndSettle();
    await t.tap(find.text('Unternehmensprofil').first);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('2 · Unternehmensprofil'));
    await t.pumpAndSettle();
    await t.tap(find.text('2 · Unternehmensprofil'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'Changed company');
    await t.ensureVisible(find.text('Speichern / Shrani'));
    await t.tap(find.text('Speichern / Shrani'));
    await t.pumpAndSettle();
    expect((posted?['workflow'] as Map?)?['snapshotId'], 's1');
    expect(posted?['year'], 2026);
    expect(find.textContaining('SNAPSHOT_CHANGED'), findsOneWidget);
    expect(t.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, 'Changed company');
    expect(t.takeException(), isNull);
  });
  testWidgets('annual import confirms the web mapping payload after preview', (t) async {
    Data? submitted;
    const fields = [
      'internal_id',
      'gender',
      'job_title',
      'worker_category',
      'base_annual',
      'bonuses_annual',
      'paid_hours_annual',
      'hours_per_week',
    ];
    await boot(
      t,
      signedIn: true,
      client: backend(
        intercept: (request) async {
          final path = request.url.path;
          http.Response json(Data data) =>
              http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
          if (path == '/api/import/preview') {
            return json({
              'count': 1,
              'headers': fields,
              'rows': [
                {'internal_id': 'P1', 'gender': 'M'},
              ],
              'mapping': {for (final field in fields) field: field},
              'quality': {
                'summary': {'errors': 0, 'warnings': 0},
                'findings': [],
              },
            });
          }
          if (path == '/api/import') {
            submitted = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
            return json({
              'snapshot': {'id': 'imported', 'count': 1},
            });
          }
          return null;
        },
      ),
    );
    final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
    container.read(routerProvider).go('/pay/import');
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'internal_id;gender\nP1;M');
    await t.scrollUntilVisible(find.text('Vorschau und Zuordnung'), 250, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('Vorschau und Zuordnung'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byType(CheckboxListTile),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
    await t.tap(find.byType(CheckboxListTile));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Jahresdaten importieren'));
    await t.pumpAndSettle();
    await t.tap(find.text('Jahresdaten importieren'));
    await t.pumpAndSettle();
    expect(submitted?['contextConfirmed'], true);
    expect(submitted?['year'], 2026);
    expect((submitted?['mapping'] as Map?)?['internal_id'], 'internal_id');
    expect(t.takeException(), isNull);
  });
}
