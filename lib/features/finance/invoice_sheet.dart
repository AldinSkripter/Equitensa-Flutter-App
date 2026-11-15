import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../core/i18n.dart';
import '../../domain/models.dart';

Color _hex(String v, Color fallback) {
  final h = v.replaceAll('#', '');
  if (h.length != 6) return fallback;
  final n = int.tryParse(h, radix: 16);
  return n == null ? fallback : Color(0xFF000000 | n);
}

const _allColumns = [
  ('position', 'Pos.', 'Št.', 8),
  ('description', 'Beschreibung', 'Opis', 38),
  ('quantity', 'Menge', 'Količina', 12),
  ('unitPrice', 'Einzelpreis', 'Cena/enoto', 17),
  ('rate', 'USt.', 'DDV', 10),
  ('discount', 'Rabatt', 'Popust', 11),
  ('total', 'Gesamt netto', 'Skupaj neto', 18),
];

/// Pixel-compatible port of the web `FinanceDocumentPreview` (A4 at 595 logical px, scaled to fit).
/// The document model and design come from the backend; the app only renders them.
class InvoiceSheet extends StatelessWidget {
  const InvoiceSheet({
    super.key,
    required this.profile,
    required this.companyName,
    required this.country,
    required this.design,
    required this.accent,
    this.doc,
    this.watermark = true,
  });

  final FinanceProfile profile;
  final String companyName;
  final Country country;
  final DocDesign design;
  final String accent;
  final FinDoc? doc;
  final bool watermark;

  static const double paperWidth = 595;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ClipRect(
      child: SizedBox(
        width: box.maxWidth,
        // Lay out at full paper width, then scale the painted result to the screen.
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: paperWidth,
            child: _Sheet(
              profile: profile,
              companyName: companyName,
              country: country,
              design: design,
              accent: accent,
              doc: doc,
              watermark: watermark,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.profile,
    required this.companyName,
    required this.country,
    required this.design,
    required this.accent,
    required this.doc,
    required this.watermark,
  });

  final FinanceProfile profile;
  final String companyName;
  final Country country;
  final DocDesign design;
  final String accent;
  final FinDoc? doc;
  final bool watermark;

  bool get _sl => country == Country.si;
  String _l(String de, String sl) => _sl ? sl : de;

  @override
  Widget build(BuildContext context) {
    final fmt = Fmt(country);
    final acc = _hex(accent, const Color(0xFF7451F8));
    final text = _hex(design.textColor, const Color(0xFF272238));
    final surface = _hex(design.surfaceColor, const Color(0xFFF4F1FC));
    final size = design.fontSize.toDouble();
    final margin = design.pageMargin * 0.7;
    final family = switch (design.font) {
      'serif' => 'Georgia',
      'mono' => 'Consolas',
      _ => 'Arial',
    };
    final fallback = switch (design.font) {
      'serif' => const ['serif', 'Inter'],
      'mono' => const ['monospace', 'Inter'],
      _ => const ['Inter'],
    };
    final template = design.template;
    final business = template == 'business';
    final compact = design.density == 'compact';
    final tableBg = design.tableStyle == 'contrast'
        ? acc
        : design.tableStyle == 'plain'
        ? Colors.white
        : surface;
    final tableText = design.tableStyle == 'contrast' ? Colors.white : acc;

    final d = doc;
    final customer = d?.customer;
    final title = d?.isOffer == true
        ? (design.offerTitle.isNotEmpty ? design.offerTitle : _l('Angebot', 'Ponudba'))
        : (design.invoiceTitle.isNotEmpty ? design.invoiceTitle : _l('Rechnung', 'Račun'));

    final columns = _allColumns.where((c) => design.columns.contains(c.$1)).toList();
    final totalWeight = columns.fold<int>(0, (a, c) => a + c.$4);
    final lines = d?.lines ?? const <DocLine>[];

    Widget blocks(String position) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in design.blocks.where((b) => b.position == position))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b.heading.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      b.heading,
                      style: TextStyle(
                        color: acc,
                        fontSize: size + 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (b.body.isNotEmpty)
                  Text(
                    b.body,
                    style: TextStyle(color: text, fontSize: size, height: 1.7),
                  ),
              ],
            ),
          ),
      ],
    );

    final logo = _logo(profile.logo, design.logoWidth * 0.75);

    Widget header() {
      final left = Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!business)
              Text(
                profile.name.isNotEmpty ? profile.name : companyName,
                style: const TextStyle(fontSize: 9),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  title,
                  textAlign: design.titleAlign == 'center'
                      ? TextAlign.center
                      : design.titleAlign == 'right'
                      ? TextAlign.right
                      : TextAlign.left,
                  style: TextStyle(
                    fontSize: design.titleSize.toDouble(),
                    color: business ? text : acc,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: 0.6,
              child: Text(
                d?.number ?? _l('ENTWURF', 'OSNUTEK'),
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      );
      final children = <Widget>[left, if (logo != null && !business) logo];
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: design.logoPosition == 'left' ? TextDirection.rtl : TextDirection.ltr,
        children: children,
      );
      final box = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 90),
        child: row,
      );
      if (template == 'editorial') {
        // Full-bleed band behind the header (web: negative margins, which Flutter's Container forbids).
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -12,
                right: -12,
                top: -15,
                bottom: 0,
                child: ColoredBox(color: surface),
              ),
              box,
            ],
          ),
        );
      }
      return business
          ? Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 18),
              child: box,
            )
          : box;
    }

    Widget party(String label, String name, List<String> rows) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: 0.5,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                label,
                style: const TextStyle(fontSize: 7, letterSpacing: 0.9),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              name,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
            ),
          ),
          for (final r in rows.where((r) => r.trim().isNotEmpty))
            Opacity(
              opacity: 0.75,
              child: Text(r, style: TextStyle(fontSize: size - 1, height: 1.7)),
            ),
        ],
      ),
    );

    final parties = Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        compact ? 15 : 25,
        0,
        business ? 24 : (compact ? 15 : 25),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          party(
            _l('VON', 'OD'),
            profile.name.isNotEmpty ? profile.name : companyName,
            [
              profile.address.isEmpty ? '—' : profile.address,
              '${profile.postalCode} ${profile.city}'.trim(),
              country.code,
              profile.vatId.isNotEmpty ? profile.vatId : profile.taxId,
            ],
          ),
          const SizedBox(width: 20),
          party(
            _l('AN', 'ZA'),
            customer?.name.isNotEmpty == true ? customer!.name : _l('Beispielkunde GmbH', 'Vzorčna stranka d.o.o.'),
            [
              customer?.address.isNotEmpty == true ? customer!.address : _l('Beispielstraße 12', 'Vzorčna ulica 12'),
              '${customer?.postalCode ?? ''} ${customer?.city ?? ''}'.trim(),
              customer?.countryCode ?? country.code,
              customer?.vatId ?? '',
            ],
          ),
        ],
      ),
    );

    Widget dateCell(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: 0.6,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(label, style: const TextStyle(fontSize: 8)),
          ),
        ),
        Text(value, style: const TextStyle(fontSize: 9)),
      ],
    );

    final dates = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: business ? const Color(0xFFDDDDDD) : const Color(0xFFEEEAF3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          dateCell(_l('Ausgestellt', 'Izdano'), d?.issueDate ?? '2026-11-14'),
          dateCell(_l('Leistung', 'Dobava'), d?.serviceDate ?? '2026-11-14'),
          dateCell(_l('Fällig', 'Zapadlost'), d?.dueDate ?? '2026-11-28'),
        ],
      ),
    );

    String money(int c) => fmt.money(c);
    String cell(String key, DocLine l, int i) => switch (key) {
      'position' => '${i + 1}',
      'description' => _description(l, columns.map((c) => c.$1).toSet(), money),
      'quantity' => '${l.quantity} ${l.unit}',
      'unitPrice' => money(((double.tryParse(l.unitPrice) ?? 0) * 100).round()),
      'rate' => '${l.rate}%',
      'discount' => '${l.discountPercent}%',
      _ => money(l.netCents),
    };

    final vPad = compact ? 7.0 : 16.0;
    final table = Table(
      columnWidths: {
        for (var i = 0; i < columns.length; i++) i: FlexColumnWidth(columns[i].$4 / totalWeight),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: tableBg),
          children: [
            for (var i = 0; i < columns.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 6,
                ),
                child: Text(
                  _l(columns[i].$2, columns[i].$3),
                  textAlign: i == columns.length - 1 ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: tableText,
                    fontSize: size,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < lines.length; r++)
          TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEAF3))),
            ),
            children: [
              for (var i = 0; i < columns.length; i++)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 6),
                  child: Text(
                    cell(columns[i].$1, lines[r], r),
                    textAlign: i == columns.length - 1 ? TextAlign.right : TextAlign.left,
                    softWrap: i != columns.length - 1,
                    style: TextStyle(fontSize: size, height: 1.6),
                  ),
                ),
            ],
          ),
      ],
    );

    Widget totalRow(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(fontSize: 10)),
          Text(v, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );

    final taxes =
        d?.taxes ??
        [
          TaxLine(
            country.standardRate,
            20000,
            (20000 * double.parse(country.standardRate) / 100).round(),
          ),
        ];
    final net = d?.netCents ?? 20000;
    final gross = d?.grossCents ?? (20000 * (1 + double.parse(country.standardRate) / 100)).round();

    final totals = Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: business ? 0.55 : 0.65,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 30),
          child: Column(
            children: [
              totalRow('Netto', money(net)),
              for (final t in taxes) totalRow('${_l('USt.', 'DDV')} ${t.rate}%', money(t.taxCents)),
              Container(
                padding: const EdgeInsets.only(top: 13),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: acc)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _l('Gesamt', 'Skupaj'),
                      style: TextStyle(
                        fontSize: 16,
                        color: acc,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      money(gross),
                      style: TextStyle(
                        fontSize: 16,
                        color: acc,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final footerText = profile.footer.isNotEmpty
        ? profile.footer
        : _l('Vielen Dank für Ihr Vertrauen.', 'Hvala za vaše zaupanje.');
    final footer = Container(
      margin: const EdgeInsets.only(top: 35),
      padding: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: business ? acc : const Color(0xFFEEEAF3)),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 8, height: 1.7, color: text),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                footerText,
                style: TextStyle(fontSize: 9, color: text),
              ),
            ),
            if (business)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: profile.name.isNotEmpty ? profile.name : companyName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text:
                                '\n${profile.address}\n${profile.postalCode} ${profile.city}\n${profile.vatId.isNotEmpty ? profile.vatId : profile.taxId}',
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: size, height: 1.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      profile.email,
                      style: TextStyle(fontSize: size, height: 1.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'IBAN\n${profile.iban.isEmpty ? '—' : profile.iban}',
                      style: TextStyle(fontSize: size, height: 1.6),
                    ),
                  ),
                ],
              )
            else
              Text(
                'IBAN: ${profile.iban.isEmpty ? '—' : profile.iban}\n${profile.email}',
              ),
          ],
        ),
      ),
    );

    final body = <Widget>[
      if (business) ...[
        parties,
        dates,
        header(),
      ] else ...[
        header(),
        parties,
        dates,
      ],
      if (d?.reference.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('${_l('Referenz', 'Referenca')}: ${d!.reference}'),
        ),
      blocks('intro'),
      table,
      blocks('afterItems'),
      totals,
      if (d?.note.isNotEmpty == true) Text(d!.note, style: const TextStyle(fontSize: 9)),
      if ('${d?.raw['taxNotice'] ?? ''}'.isNotEmpty)
        Text(d!.raw['taxNotice'].toString(), style: const TextStyle(fontSize: 9)),
      blocks('closing'),
      footer,
      if (watermark)
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Center(
            child: Text(
              _l(
                'DESIGNVORSCHAU · KEIN AUSGESTELLTER BELEG',
                'PREDOGLED · NI IZDAN DOKUMENT',
              ),
              style: const TextStyle(
                fontSize: 7,
                letterSpacing: 0.7,
                color: Color(0xFFA491B5),
              ),
            ),
          ),
        ),
    ];

    return Container(
      constraints: const BoxConstraints(minHeight: 842),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: template == 'signature' ? Border(top: BorderSide(color: acc, width: 6)) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A30233F),
            blurRadius: 35,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x123F2750),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        margin,
        business ? 110 : margin,
        margin,
        margin,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: text,
          fontSize: size,
          fontFamily: family,
          fontFamilyFallback: fallback,
          height: 1.4,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: body,
            ),
            if (business && logo != null)
              Positioned(
                top: -(110 - 30) + 0,
                left: design.logoPosition == 'left' ? 0 : null,
                right: design.logoPosition == 'left' ? null : 0,
                child: logo,
              ),
          ],
        ),
      ),
    );
  }

  static String _description(
    DocLine l,
    Set<String> keys,
    String Function(int) money,
  ) {
    final details = <String>[];
    if (!keys.contains('quantity')) details.add('${l.quantity} ${l.unit}');
    if (!keys.contains('unitPrice')) {
      details.add(
        'Einzelpreis: ${money(((double.tryParse(l.unitPrice) ?? 0) * 100).round())}',
      );
    }
    if (l.discountCents != 0 && !keys.contains('discount')) details.add('Rabatt: ${l.discountPercent}%');
    return l.description + (details.isEmpty ? '' : '\n${details.join(' · ')}');
  }

  Widget? _logo(String data, double width) {
    if (data.isEmpty) return null;
    try {
      final bytes = base64Decode(
        data.contains(',') ? data.split(',').last : data,
      );
      return Padding(
        padding: const EdgeInsets.only(left: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: 65),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
