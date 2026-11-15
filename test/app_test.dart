import 'dart:convert';

import 'package:equitensa/app.dart';
import 'package:equitensa/core/providers.dart';
import 'package:equitensa/data/api_client.dart';
import 'package:equitensa/domain/models.dart';
import 'package:equitensa/features/finance/invoice_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Shapes copied from real responses of the Equitensa backend (demo mode).
const _contact = {
  'id': 'c1',
  'name': 'Studio Nord GmbH',
  'address': 'Testgasse 8',
  'postalCode': '20095',
  'city': 'Hamburg',
  'country': 'DE',
  'vatId': 'DE987654321',
  'email': 'k@example.com',
  'business': true,
  'publicBody': false,
};

Map<String, dynamic> _doc({
  String status = 'draft',
  List<Map<String, dynamic>> payments = const [],
}) => {
  'id': 'd1',
  'kind': 'invoice',
  'status': status,
  'number': status == 'draft' ? null : 'RE-2026-00001',
  'contactId': 'c1',
  'customer': _contact,
  'issueDate': '2026-11-15',
  'serviceDate': '2026-11-15',
  'dueDate': '2026-11-29',
  'reference': '',
  'note': 'Vielen Dank.',
  'appearance': null,
  'lines': [
    {
      'description': 'Design und Beratung',
      'unit': 'h',
      'quantity': '2.5',
      'unitPrice': '120.00',
      'rate': '19',
      'discountPercent': '0',
      'discountCents': 0,
      'netCents': 30000,
    },
    {
      'description': 'Konzept',
      'unit': 'Stk.',
      'quantity': '1',
      'unitPrice': '480.00',
      'rate': '19',
      'discountPercent': '0',
      'discountCents': 0,
      'netCents': 48000,
    },
  ],
  'taxes': [
    {'rate': '19', 'netCents': 78000, 'taxCents': 14820},
  ],
  'netCents': 78000,
  'taxCents': 14820,
  'grossCents': 92820,
  'payments': payments,
  'createdAt': '2026-11-15T10:00:00.000Z',
};

Map<String, dynamic> _financeJson({
  List<Map<String, dynamic>> docs = const [],
}) => {
  'state': {
    'revision': 3,
    'country': 'DE',
    'countryConfirmed': true,
    'profile': {
      'name': 'Demo Atelier GmbH',
      'address': 'Musterstraße 12',
      'postalCode': '10115',
      'city': 'Berlin',
      'taxId': '',
      'vatId': 'DE123456789',
      'iban': 'DE89370400440532013000',
      'email': 'o@x.de',
      'logo': '',
      'accent': '#7451f8',
      'footer': 'Danke',
    },
    'contacts': [_contact],
    'documents': docs,
    'expenses': [],
    'sequence': {},
    'subscription': null,
    'events': [],
  },
  'country': {
    'name': 'Deutschland',
    'locale': 'de-DE',
    'standardRate': '19',
    'rates': ['19', '7'],
  },
  'plans': [
    {
      'id': 'finance_start',
      'name': 'Rechnungen',
      'monthlyCents': 799,
      'includedSeats': 1,
    },
    {
      'id': 'finance_business',
      'name': 'Business',
      'monthlyCents': 1999,
      'includedSeats': 2,
    },
    {
      'id': 'finance_pro',
      'name': 'Pro',
      'monthlyCents': 2999,
      'includedSeats': 3,
    },
  ],
  'demo': true,
  'stage': 'development',
  'capabilities': {},
};

http.Client _fakeBackend({bool signedIn = false}) => MockClient((req) async {
  jsonResponse(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  final path = req.url.path;
  if (path == '/api/health') return jsonResponse({'status': 'ok', 'mode': 'demo'});
  if (path == '/api/me') {
    return signedIn
        ? jsonResponse({
            'company': {
              'id': 'co',
              'name': 'Demo Atelier GmbH',
              'country': 'DE',
            },
            'user': {
              'email': 'a@b.de',
              'role': 'hr_manager',
              'emailVerified': true,
              'mfaEnabled': false,
            },
            'demo': true,
          })
        : jsonResponse({'error': 'AUTH_REQUIRED'}, 401);
  }
  if (path == '/api/finance') return jsonResponse(_financeJson(docs: [_doc()]));
  if (path == '/api/auth/login') {
    final b = jsonDecode(req.body) as Map;
    return b['password'] == 'correct-horse-battery'
        ? jsonResponse({'ok': true})
        : jsonResponse({'error': 'INVALID_LOGIN'}, 401);
  }
  return jsonResponse({'error': 'NOT_FOUND'}, 404);
});

Future<void> boot(WidgetTester t, {bool signedIn = false, http.Client? client}) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(
            baseUrl: 'http://test',
            client: client ?? _fakeBackend(signedIn: signedIn),
            persist: false,
          ),
        ),
      ],
      child: const EquitensaApp(),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The real brand font, so layout tests measure text like the device does (not the Ahem test font).
  setUpAll(() async {
    final loader = FontLoader('Inter');
    for (final w in ['400Regular', '500Medium', '600SemiBold', '700Bold', '800ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter_$w.ttf'));
    }
    await loader.load();
  });

  group('models', () {
    test('FinDoc parses the backend document and derives payment state', () {
      final d = FinDoc.fromJson(
        _doc(
          status: 'issued',
          payments: [
            {
              'id': 'p',
              'amountCents': 40000,
              'paidOn': '2026-11-16',
              'reference': '',
            },
          ],
        ),
      );
      expect(d.grossCents, 92820);
      expect(d.paidCents, 40000);
      expect(d.outstandingCents, 52820);
      expect(d.isUnpaid, isTrue);
      expect(d.isOverdue('2026-12-01'), isTrue);
      expect(d.isOverdue('2026-11-20'), isFalse);
    });

    test(
      'DocDesign merges defaults < profile < appearance like the web composer',
      () {
        final d = DocDesign.merge([
          {'template': 'editorial', 'fontSize': 11},
          {'template': 'business'},
        ]);
        expect(d.template, 'business');
        expect(d.fontSize, 11);
        expect(d.font, 'sans');
        expect(d.columns, contains('total'));
      },
    );

    test(
      'plan features mirror the server gate (no plan = full exploration)',
      () {
        final snap = FinanceSnapshot.fromJson(_financeJson());
        expect(snap.hasFeature('expenses'), isTrue);
        final start = FinanceSnapshot.fromJson({
          ..._financeJson(),
          'state': {
            ...(_financeJson()['state'] as Map<String, dynamic>),
            'subscription': {'plan': 'finance_start'},
          },
        });
        expect(start.hasFeature('expenses'), isFalse);
        expect(start.hasFeature('recurring'), isFalse);
      },
    );
  });

  group('invoice sheet', () {
    for (final template in ['signature', 'minimal', 'editorial', 'business']) {
      testWidgets('renders the $template template without layout errors', (
        t,
      ) async {
        t.view.physicalSize = const Size(1080, 2400);
        t.view.devicePixelRatio = 2.75;
        addTearDown(t.view.reset);
        final profile = FinanceProfile.fromJson(
          (_financeJson()['state'] as Map)['profile'] as Map<String, dynamic>,
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InvoiceSheet(
                  profile: profile,
                  companyName: 'Demo',
                  country: Country.de,
                  design: DocDesign.merge([
                    {
                      'template': template,
                      'font': 'serif',
                      'tableStyle': 'contrast',
                    },
                  ]),
                  accent: '#245aa5',
                  doc: FinDoc.fromJson(_doc()),
                ),
              ),
            ),
          ),
        );
        await t.pump();
        expect(find.text('Rechnung'), findsWidgets);
        expect(find.textContaining('928,20'), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('auth', () {
    testWidgets('auth adapts to a narrow phone, keyboard and desktop', (t) async {
      await boot(t);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 640);
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('Anmelden'));
      await t.tap(find.text('Anmelden'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pump(const Duration(milliseconds: 500));
      await t.ensureVisible(find.byType(TextField).last);
      expect(t.takeException(), isNull);
      t.view.viewInsets = const FakeViewPadding();
      t.view.physicalSize = const Size(1440, 900);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Mehr Klarheit.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('signed-out user lands on the welcome screen', (t) async {
      await boot(t);
      expect(find.textContaining('Fair bezahlen'), findsOneWidget);
      expect(find.text('Weiter'), findsOneWidget);
    });

    testWidgets('login shows the server error for wrong credentials', (
      t,
    ) async {
      await boot(t);
      await t.tap(find.text('Anmelden'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'chef@firma.de');
      await t.enterText(fields.at(1), 'wrong-password');
      await t.tap(find.text('Anmelden').last);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('E-Mail oder Passwort stimmt nicht.'), findsOneWidget);
    });

    testWidgets('register shows company first and validates the web fields', (
      t,
    ) async {
      await boot(t);
      await t.tap(find.text('Überspringen'));
      await t.pumpAndSettle();
      await t.tap(find.text('Konto erstellen'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
      final fields = find.byType(TextField);
      expect(t.widget<TextField>(fields.first).autofillHints, contains(AutofillHints.organizationName));
      await t.enterText(fields.at(0), 'Studio Nord GmbH');
      await t.enterText(fields.at(1), 'chef@firma.de');
      await t.enterText(fields.at(2), 'kurz');
      await t.ensureVisible(find.text('Konto erstellen & weiter'));
      await t.tap(find.text('Konto erstellen & weiter'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Mindestens 12 Zeichen.'), findsOneWidget);
    });

    testWidgets('introduction supports next, swipe and skip', (t) async {
      await boot(t);
      await t.tap(find.text('Weiter'));
      await t.pumpAndSettle();
      expect(find.textContaining('Aus Zahlen'), findsOneWidget);
      await t.drag(find.byType(PageView), const Offset(-330, 0));
      await t.pumpAndSettle();
      expect(find.text('Konto erstellen'), findsOneWidget);
      await t.tap(find.text('Konto erstellen'));
      await t.pumpAndSettle();
      expect(find.text('Unternehmensname'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('registration sends the web payload and opens email verification', (t) async {
      Map<String, dynamic>? submitted;
      final client = MockClient((request) async {
        http.Response json(Object value, [int status = 200]) =>
            http.Response(jsonEncode(value), status, headers: {'content-type': 'application/json'});
        if (request.url.path == '/api/health') return json({'mode': 'database'});
        if (request.url.path == '/api/auth/register') {
          submitted = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return json({
            'company': {'id': 'new-company', 'name': submitted!['companyName'], 'country': submitted!['country']},
          }, 201);
        }
        if (request.url.path == '/api/me' && submitted != null) {
          return json({
            'company': {'id': 'new-company', 'name': submitted!['companyName'], 'country': submitted!['country']},
            'user': {'email': submitted!['email'], 'role': 'hr_manager', 'emailVerified': false, 'mfaEnabled': false},
            'demo': false,
          });
        }
        return json({'error': 'AUTH_REQUIRED'}, 401);
      });
      await boot(t, client: client);
      await t.tap(find.text('Überspringen'));
      await t.pumpAndSettle();
      await t.tap(find.text('Konto erstellen'));
      await t.pumpAndSettle();
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'Studio Nord GmbH');
      await t.enterText(fields.at(1), 'chef@firma.de');
      await t.enterText(fields.at(2), 'Correct-Password-2026!');
      await t.ensureVisible(find.text('Konto erstellen & weiter'));
      await t.tap(find.text('Konto erstellen & weiter'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(submitted, {
        'companyName': 'Studio Nord GmbH',
        'email': 'chef@firma.de',
        'password': 'Correct-Password-2026!',
        'country': 'DE',
      });
      expect(find.text('Prüfen Sie Ihr Postfach'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('signed-in app', () {
    testWidgets('shows the Finance overview with the PAY/FINANCE switch', (
      t,
    ) async {
      await boot(t, signedIn: true);
      expect(find.text('FINANCE'), findsOneWidget);
      expect(find.text('PAY'), findsOneWidget);
      expect(find.text('Übersicht'), findsWidgets);
      final create = find.byTooltip('Neu erstellen');
      expect(t.getCenter(create).dx, closeTo(t.view.physicalSize.width / t.view.devicePixelRatio / 2, .5));
      await t.tap(create);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('NEU ERSTELLEN'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
