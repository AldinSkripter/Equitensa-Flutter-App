import 'package:equitensa/core/i18n.dart';
import 'package:equitensa/core/theme.dart';
import 'package:equitensa/features/pay/pay_readiness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('server readiness controls status and next action independently of percentage', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? target;
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportProgress(
                readiness: {
                  'ready': false,
                  'percent': 100,
                  'checks': [
                    for (final id in reportSteps) {'id': id, 'done': id != 'approval'},
                  ],
                },
                t: const Tr('de'),
                onStep: (id) => target = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Für den Bericht vorbereitet'), findsNothing);
      expect(find.text('4 von 5 Prüfungen abgeschlossen'), findsOneWidget);
      await tester.ensureVisible(find.text('Nächsten Schritt bearbeiten'));
      await tester.tap(find.text('Nächsten Schritt bearbeiten'));
      expect(target, 'approval');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('missing requirements retain server article and category with readable labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ReportSectionStatus(
              title: 'Kriterien & Arbeitsbewertung',
              done: false,
              t: Tr('de'),
              missing: [
                {'field': 'classification', 'category': 'Engineering', 'article': '4(4)'},
                {'field': 'evaluation', 'category': 'weights', 'article': '4, 10(4)'},
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Alle vier Vergleichskriterien beschreiben · Engineering'), findsOneWidget);
    expect(find.text('Art. 4(4)'), findsOneWidget);
    expect(find.textContaining('Gewichte: zusammen 100 %'), findsOneWidget);
    expect(find.text('Noch offen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
