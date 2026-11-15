import 'dart:convert';

import 'package:equitensa/app.dart';
import 'package:equitensa/core/providers.dart';
import 'package:equitensa/core/appearance.dart';
import 'package:equitensa/core/theme.dart';
import 'package:equitensa/core/ui.dart';
import 'package:equitensa/data/api_client.dart';
import 'package:equitensa/domain/models.dart';
import 'package:equitensa/features/finance/invoice_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.value = 'light']);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String mode) async {
    value = mode;
  }
}

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
  if (path == '/api/analysis') {
    return jsonResponse({
      'year': 2026,
      'analysis': {
        'count': 20,
        'male_count': 10,
        'female_count': 10,
        'other_count': 0,
        'mean_gap': .08,
        'median_gap': .06,
        'groups': [],
        'suppressed': false,
      },
    });
  }
  if (path == '/api/workflow') {
    return jsonResponse({
      'readiness': {
        'percent': 20,
        'ready': false,
        'checks': [
          {'id': 'profile', 'done': true},
          {'id': 'categories', 'done': false},
          {'id': 'import', 'done': false},
          {'id': 'review', 'done': false},
          {'id': 'release', 'done': false},
        ],
      },
    });
  }
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
        appearanceStoreProvider.overrideWithValue(MemoryAppearanceStore()),
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

  testWidgets('native security enrollment uses the backend and acknowledges recovery codes', (t) async {
    var enabled = false;
    final fallback = _fakeBackend(signedIn: true);
    final calls = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth/security') {
        return http.Response(
          jsonEncode({'mfaEnabled': enabled, 'hasPassword': false, 'backupCodesLeft': enabled ? 10 : 0}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.startsWith('/api/auth/mfa/')) {
        calls.add(path);
        final input = jsonDecode(request.body) as Map;
        if (path.endsWith('/setup')) {
          return http.Response(
            jsonEncode({
              'secret': 'JBSWY3DPEHPK3PXP',
              'otpauth': 'otpauth://totp/Equitensa:test?secret=JBSWY3DPEHPK3PXP&issuer=Equitensa',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(input['code'], '123456');
        enabled = path.endsWith('/enable');
        return http.Response(
          jsonEncode({'ok': true, if (enabled) 'backupCodes': List.generate(10, (i) => 'recovery-code-$i')}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await fallback.send(copy));
    });
    await boot(t, signedIn: true, client: client);
    final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
    container.read(routerProvider).go('/account/security');
    await t.pumpAndSettle();
    await t.tap(find.text('Authenticator einrichten'));
    await t.pumpAndSettle();
    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).last, '123456');
    await t.ensureVisible(find.text('Bestätigen und aktivieren'));
    await t.tap(find.text('Bestätigen und aktivieren'));
    await t.pumpAndSettle();
    expect(find.textContaining('recovery-code-0'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Codes gespeichert'));
    await t.pumpAndSettle();
    await t.tap(find.text('Codes gespeichert'));
    await t.pumpAndSettle();
    expect(find.textContaining('recovery-code-0'), findsNothing);
    await t.enterText(find.byType(TextFormField).last, '123456');
    await t.ensureVisible(find.text('Zwei-Faktor-Anmeldung deaktivieren'));
    await t.tap(find.text('Zwei-Faktor-Anmeldung deaktivieren'));
    await t.pumpAndSettle();
    expect(enabled, isFalse);
    expect(calls, ['/api/auth/mfa/setup', '/api/auth/mfa/enable', '/api/auth/mfa/disable']);
    expect(t.takeException(), isNull);
  });

  group('auth', () {
    testWidgets('language menu changes language without changing company country', (t) async {
      await boot(t);
      final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
      await t.tap(find.byTooltip('Sprache / Jezik'));
      await t.pumpAndSettle();
      await t.tap(find.text('Slovenian'));
      await t.pumpAndSettle();
      expect(container.read(languageProvider), 'sl');
      expect(container.read(authCountryProvider), Country.de);
      expect(find.text('Naprej'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets('all introduction steps fit a small phone in both appearances', (t) async {
      await boot(t);
      final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 640);
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await container.read(appearanceProvider.notifier).set(mode);
        container.read(routerProvider).go('/welcome');
        await t.pumpAndSettle();
        for (var step = 0; step < 3; step++) {
          await t.ensureVisible(find.text(step == 2 ? 'Konto erstellen' : 'Weiter'));
          expect(t.takeException(), isNull);
          if (step < 2) {
            await t.tap(find.text('Weiter'));
            await t.pumpAndSettle();
          }
        }
        await t.drag(find.byType(PageView), const Offset(700, 0));
        await t.pumpAndSettle();
        await t.drag(find.byType(PageView), const Offset(700, 0));
        await t.pumpAndSettle();
      }
    });

    testWidgets('changing appearance keeps registration input in both modes', (t) async {
      await boot(t);
      final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
      container.read(routerProvider).go('/register');
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'My Company');
      await t.tap(find.byType(AppearanceButton));
      await t.pumpAndSettle();
      expect(container.read(appearanceProvider), ThemeMode.dark);
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        await container.read(appearanceProvider.notifier).set(mode);
        await t.pumpAndSettle();
        expect(t.widget<TextField>(find.byType(TextField).first).controller!.text, 'My Company');
        expect(t.takeException(), isNull);
      }
      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      await t.pumpAndSettle();
      expect(Theme.of(t.element(find.byType(TextField).first)).brightness, Brightness.light);
    });
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
      expect(find.textContaining('Ihr Business.'), findsOneWidget);
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
      expect(find.textContaining('Faire '), findsOneWidget);
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
    testWidgets('returning from the web refreshes server data without changing appearance', (t) async {
      var financeReads = 0;
      final backend = _fakeBackend(signedIn: true);
      final client = MockClient((request) async {
        if (request.url.path == '/api/finance') {
          financeReads++;
          final payload = _financeJson(docs: [_doc()]);
          (payload['state'] as Map)['revision'] = financeReads > 1 ? 4 : 3;
          return http.Response(jsonEncode(payload), 200, headers: {'content-type': 'application/json'});
        }
        return backend.get(request.url);
      });
      await boot(t, signedIn: true, client: client);
      final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
      await container.read(appearanceProvider.notifier).set(ThemeMode.dark);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(container.read(financeProvider).value!.state.revision, 4);
      expect(container.read(appearanceProvider), ThemeMode.dark);
      expect(t.takeException(), isNull);
    });

    testWidgets('all native screens render in light and dark appearance', (t) async {
      await boot(t, signedIn: true);
      final container = ProviderScope.containerOf(t.element(find.byType(EquitensaApp)));
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        await container.read(appearanceProvider.notifier).set(mode);
        for (final route in [
          '/finance',
          '/finance/sales',
          '/finance/contacts',
          '/finance/expenses',
          '/finance/contact',
          '/finance/compose?kind=invoice',
          '/finance/document/d1',
          '/finance/company',
          '/finance/plans',
          '/account',
          '/pay',
          '/pay/report',
          '/pay/categories',
        ]) {
          container.read(routerProvider).go(route);
          for (var frame = 0; frame < 8; frame++) {
            await t.pump(const Duration(milliseconds: 200));
          }
          expect(t.takeException(), isNull, reason: '$mode $route');
          final scaffold = find.byType(Scaffold).last;
          expect(
            Theme.of(t.element(scaffold)).brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
            reason: route,
          );
        }
      }
    });
    testWidgets('shows the Finance overview with the PAY/FINANCE switch', (
      t,
    ) async {
      await boot(t, signedIn: true);
      expect(find.text('FINANCE'), findsOneWidget);
      expect(find.text('PAY'), findsOneWidget);
      expect(find.text('Übersicht'), findsWidgets);
      final create = find.byTooltip('Neu erstellen');
      final createButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Neu erstellen',
      );
      expect(t.widget<IconButton>(createButton).style!.foregroundColor!.resolve({}), Colors.white);
      expect(t.getCenter(create).dx, closeTo(t.view.physicalSize.width / t.view.devicePixelRatio / 2, .5));
      await t.tap(create);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('NEU ERSTELLEN'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('completion percentage stays inside a properly sized ring', (t) async {
    for (final dark in [false, true]) {
      for (final percent in [0, 20, 100]) {
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(brightness: dark ? Brightness.dark : Brightness.light),
            home: Scaffold(
              body: Center(
                child: CompletionRing(percent: percent, label: 'Fortschritt'),
              ),
            ),
          ),
        );
        final progress = find.byType(CircularProgressIndicator);
        expect(t.getSize(progress), const Size(68, 68));
        expect(t.takeException(), isNull);
      }
    }
  });
}
