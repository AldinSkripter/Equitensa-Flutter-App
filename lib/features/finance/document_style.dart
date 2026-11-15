import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../workspace/workspace_widgets.dart';

const documentStyleFields = [
  Input('accent', 'Akzentfarbe #RRGGBB', 'Poudarna barva #RRGGBB'),
  Input('design.textColor', 'Textfarbe #RRGGBB', 'Barva besedila #RRGGBB'),
  Input('design.surfaceColor', 'Flächenfarbe #RRGGBB', 'Barva površine #RRGGBB'),
  Input(
    'design.template',
    'Vorlage',
    'Predloga',
    options: {'signature': 'Signature', 'minimal': 'Minimal', 'editorial': 'Editorial', 'business': 'Business'},
  ),
  Input('design.font', 'Schrift', 'Pisava', options: {'sans': 'Sans', 'serif': 'Serif', 'mono': 'Mono'}),
  Input(
    'design.density',
    'Abstände',
    'Razmiki',
    options: {'comfortable': 'Großzügig / Zračno', 'compact': 'Kompakt / Kompaktno'},
  ),
  Input(
    'design.logoPosition',
    'Logo-Position',
    'Položaj logotipa',
    options: {'left': 'Links / Levo', 'right': 'Rechts / Desno'},
  ),
  Input('design.fontSize', 'Schriftgröße 9–13', 'Velikost pisave 9–13', kind: 'number'),
  Input('design.logoWidth', 'Logo-Breite 50–150', 'Širina logotipa 50–150', kind: 'number'),
  Input('design.pageMargin', 'Seitenrand 30–60', 'Rob strani 30–60', kind: 'number'),
  Input('design.titleSize', 'Titelgröße 18–36', 'Velikost naslova 18–36', kind: 'number'),
  Input(
    'design.titleAlign',
    'Titel-Ausrichtung',
    'Poravnava naslova',
    options: {'left': 'Links / Levo', 'center': 'Mitte / Sredina', 'right': 'Rechts / Desno'},
  ),
  Input(
    'design.tableStyle',
    'Tabellenstil',
    'Slog tabele',
    options: {'soft': 'Soft', 'plain': 'Plain', 'contrast': 'Contrast'},
  ),
  Input(
    'design.columns',
    'Spalten und Reihenfolge',
    'Stolpci in vrstni red',
    kind: 'list',
    options: {
      'position': 'Position / Postavka',
      'description': 'Beschreibung / Opis',
      'quantity': 'Menge / Količina',
      'unitPrice': 'Preis / Cena',
      'total': 'Gesamt / Skupaj',
      'rate': 'USt. / DDV',
      'discount': 'Rabatt / Popust',
    },
  ),
  Input('design.invoiceTitle', 'Rechnungstitel', 'Naslov računa'),
  Input('design.offerTitle', 'Angebotstitel', 'Naslov ponudbe'),
  Input('design.paymentQr', 'Zahlungs-QR anzeigen', 'Prikaži plačilni QR', kind: 'bool'),
  Input('design.qrPosition', 'QR-Position', 'Položaj QR', options: {'left': 'Links / Levo', 'right': 'Rechts / Desno'}),
];

class PaymentQrAction extends ConsumerWidget {
  const PaymentQrAction({super.key, required this.draft});
  final Data Function() draft;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return AsyncAction(
      label: t('Zahlungs-QR prüfen', 'Preveri plačilni QR'),
      action: () async {
        final result = await ref.read(apiClientProvider).postJson('/finance/qr-preview', draft());
        final qr = object(result['qr']);
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(t('Zahlungs-QR', 'Plačilni QR')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (qr['image'] != null)
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: SvgPicture.memory(base64Decode(qr['image'].toString().split(',').last)),
                  ),
                Text(
                  qr['testOnly'] == true
                      ? t('TEST · Kein Zahlungscode', 'TEST · Ni plačilna koda')
                      : qr['image'] == null
                      ? t(
                          'QR im Design aktivieren und Bankdaten ergänzen.',
                          'V izgledu omogočite QR in dopolnite bančne podatke.',
                        )
                      : '${qr['format']}',
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
      },
    );
  }
}
