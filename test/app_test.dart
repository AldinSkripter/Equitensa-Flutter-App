import 'package:equitensa/app.dart';
import 'package:equitensa/core/l10n.dart';
import 'package:equitensa/core/providers.dart';
import 'package:equitensa/data/mock_repository.dart';
import 'package:equitensa/domain/models.dart';
import 'package:equitensa/domain/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> boot(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2200);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(retry: (_, _) => null, child: const EquitensaApp()),
  );
  await settle(t);
}

Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await settle(t);
}

void main() {
  test('every string exists in de, sl and en', () {
    for (final e in S.strings.entries) {
      for (final l in ['de', 'sl', 'en']) {
        expect(e.value[l], isNotEmpty, reason: '${e.key} missing $l');
      }
    }
  });

  test('country defaults: DE/AT German, SI Slovenian', () {
    expect(Country.de.defaultLanguage, 'de');
    expect(Country.at.defaultLanguage, 'de');
    expect(Country.si.defaultLanguage, 'sl');
  });

  test('mock calculation uses integer cents and country VAT', () async {
    final repo = MockRepository(() => const DemoFlags());
    final t = await repo.calculate(const [
      InvoiceLine(
        description: 'Consulting',
        quantity: '1',
        unitPrice: '125.00',
        rate: 20,
      ),
    ]);
    expect((t.netCents, t.taxCents, t.grossCents), (12500, 2500, 15000));
  });

  test(
    'stale revision raises a version conflict; offline raises offline',
    () async {
      var flags = const DemoFlags();
      final repo = MockRepository(() => flags);
      await repo.selectCompany('de-1');
      final contact = (await repo.contacts()).first;
      await expectLater(
        repo.saveDraft(
          revision: 99,
          contact: contact,
          issueDate: DateTime(2026, 11, 15),
          dueDate: DateTime(2026, 11, 29),
          lines: const [],
        ),
        throwsA(isA<VersionConflictException>()),
      );
      flags = const DemoFlags(offline: true);
      await expectLater(repo.invoices(), throwsA(isA<OfflineException>()));
    },
  );

  test('Rechnungen package has no expenses; Business does', () {
    expect(FinancePlan.start.hasExpenses, isFalse);
    expect(FinancePlan.business.hasExpenses, isTrue);
    expect(FinancePlan.pro.hasRecurring, isTrue);
    expect(FinancePlan.business.hasRecurring, isFalse);
  });

  testWidgets('SI company: Slovenian UI, Pay locked with explanation', (
    t,
  ) async {
    await boot(t);
    await tapVisible(t, find.textContaining('Demo Atelje'));
    expect(find.text('Pregled'), findsWidgets);
    await tapVisible(t, find.text('PAY'));
    expect(find.text('PAY za to podjetje ni aktiviran'), findsOneWidget);
  });

  testWidgets('DE company: invoice editor keeps input on version conflict', (
    t,
  ) async {
    await boot(t);
    await tapVisible(t, find.textContaining('Deutschland'));
    expect(find.text('Übersicht'), findsWidgets);

    final container = ProviderScope.containerOf(
      t.element(find.byType(EquitensaApp)),
    );
    container.read(demoFlagsProvider.notifier).setConflict(true);

    await tapVisible(t, find.text('Rechnungen'));
    await tapVisible(t, find.byType(FloatingActionButton));
    await tapVisible(t, find.text('Kunde auswählen'));
    await tapVisible(t, find.text('Nordlicht Studio GmbH'));
    await t.enterText(
      find.widgetWithText(TextField, 'Beschreibung'),
      'Beratung',
    );
    await t.enterText(find.widgetWithText(TextField, 'Einzelpreis'), '125');
    await settle(t);
    await tapVisible(t, find.text('Entwurf speichern'));
    expect(find.text('Daten wurden geändert'), findsOneWidget);
    await tapVisible(t, find.text('Weiter bearbeiten'));
    expect(find.text('Beratung'), findsOneWidget);
  });
}
