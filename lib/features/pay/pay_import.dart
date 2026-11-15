import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/ui.dart';
import '../../core/files.dart';
import '../../data/api_client.dart';
import '../finance/finance_common.dart';
import '../workspace/workspace_widgets.dart';

const annualFields = [
  'internal_id',
  'gender',
  'job_title',
  'worker_category',
  'job_category_kv',
  'base_annual',
  'bonuses_annual',
  'paid_hours_annual',
  'hours_per_week',
];
const hrFields = [
  'internal_id',
  'gender',
  'job_title',
  'worker_category',
  'hours_per_week',
  'first_month',
  'last_month',
];
const transactionFields = [
  'transaction_id',
  'internal_id',
  'period',
  'pay_code',
  'amount',
  'currency',
  'paid_hours',
  'correction_ref',
];
const importLabels = {
  'internal_id': 'Personalnummer / Šifra zaposlenega',
  'gender': 'Geschlecht / Spol',
  'job_title': 'Tätigkeit / Delovno mesto',
  'worker_category': 'Gleichwertige Kategorie / Enakovredna kategorija',
  'job_category_kv': 'KV-Stufe / Stopnja KP',
  'base_annual': 'Jahresgrundvergütung / Letno osnovno plačilo',
  'bonuses_annual': 'Variable Jahresvergütung / Letno variabilno plačilo',
  'paid_hours_annual': 'Bezahlte Jahresstunden / Letne plačane ure',
  'hours_per_week': 'Wochenstunden / Tedenske ure',
  'first_month': 'Erster Monat / Prvi mesec',
  'last_month': 'Letzter Monat / Zadnji mesec',
  'transaction_id': 'Buchungs-ID / Šifra transakcije',
  'period': 'Monat YYYY-MM / Mesec YYYY-MM',
  'pay_code': 'Entgeltart / Obračunska šifra',
  'amount': 'Bruttobetrag / Bruto znesek',
  'currency': 'Währung / Valuta',
  'paid_hours': 'Bezahlte Stunden / Plačane ure',
  'correction_ref': 'Korrektur-Referenz / Sklic popravka',
};

class PayImportScreen extends ConsumerStatefulWidget {
  const PayImportScreen({super.key, this.batchId});
  final String? batchId;
  @override
  ConsumerState<PayImportScreen> createState() => _PayImportState();
}

class _PayImportState extends ConsumerState<PayImportScreen> {
  String _kind = 'annual';
  Data? _file, _preview, _quality;
  Data _mapping = {}, _fixes = {};
  final _csv = TextEditingController();
  final Data _selection = {'headerRow': 1, 'decimalSeparator': '.', 'source': 'payroll'};
  bool _busy = false, _confirmed = false, _warnings = false;
  String? _batch;
  int? _ledgerVersion;
  Data? _assistant;
  List<Data> _issues = [];
  @override
  void initState() {
    super.initState();
    _batch = widget.batchId;
  }

  @override
  void dispose() {
    _csv.dispose();
    _file = null;
    _preview = null;
    super.dispose();
  }

  Data _payload() => {
    if (_batch != null) 'batchId': _batch else if (_file != null) 'file': _file else 'csv': _csv.text,
    'year': ref.read(payYearProvider),
    if (_kind != 'annual') 'kind': _kind,
    ..._selection,
  };
  void _invalidate() {
    _preview = null;
    _quality = null;
    _confirmed = false;
    _warnings = false;
    _fixes = {};
    _assistant = null;
    _issues = [];
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      await work();
    } catch (e) {
      if (mounted && e is ApiException) setState(() => _issues = records(e.details['errors']));
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() => _run(() async {
    final selected = await pickDocument();
    if (selected == null || !mounted) return;
    final file = selected;
    if (file.bytes.length > 4 * 1024 * 1024) throw StateError('Maximal 4 MB');
    setState(() {
      _file = {'name': file.name, 'base64': base64Encode(file.bytes)};
      _batch = null;
      for (final key in ['sheet', 'recordPath', 'zipEntry']) {
        _selection.remove(key);
      }
      _selection['headerRow'] = 1;
      _csv.clear();
      _invalidate();
    });
  });
  Future<void> _check() async {
    if (_kind != 'annual') return;
    final result = await ref.read(apiClientProvider).postJson('/import/quality', {
      ..._payload(),
      'mapping': _mapping,
      'fixes': _fixes,
    });
    if (mounted) {
      setState(() {
        _quality = result;
        _confirmed = false;
        _warnings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref), year = ref.watch(payYearProvider);
    final fields = _kind == 'annual'
        ? annualFields
        : _kind == 'hr'
        ? hrFields
        : transactionFields;
    final headers = (_preview?['headers'] as List? ?? []).map((h) => h.toString()).toSet();
    return SubPage(
      title: t('Daten importieren', 'Uvoz podatkov'),
      kicker: 'PAY · $year',
      child: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: t('Datenquelle', 'Vir podatkov')),
              items: [
                DropdownMenuItem(value: 'annual', child: Text(t('Jahresdaten', 'Letni podatki'))),
                DropdownMenuItem(
                  value: 'hr',
                  child: Text(t('Monatlich · Personalstamm', 'Mesečno · kadrovski podatki')),
                ),
                DropdownMenuItem(
                  value: 'transactions',
                  child: Text(t('Monatlich · Buchungen', 'Mesečno · transakcije')),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _kind = v!;
                      _invalidate();
                    }),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () =>
                  shareBytes(utf8.encode('${annualFields.join(';')}\n'), 'equitensa-template.csv', 'text/csv'),
              child: Text(t('CSV-Vorlage herunterladen', 'Prenesi predlogo CSV')),
            ),
            for (final issue in _issues)
              NoticeBanner('${issue['row'] ?? ''} · ${issue['column'] ?? issue['field'] ?? ''} · ${issue['error']}'),
            NoticeBanner(
              t(
                'Bis 4 MB. Der Server prüft Datei, Land, Jahr und EUR. Ein Jahresimport ersetzt den aktuellen Datenstand; Freigaben müssen erneut geprüft werden.',
                'Do 4 MB. Strežnik preveri datoteko, državo, leto in EUR. Letni uvoz nadomesti trenutni posnetek; potrditve je treba ponovno preveriti.',
              ),
            ),
            const SizedBox(height: 18),
            EqButton(
              label:
                  _file?['name']?.toString() ??
                  (_batch == null
                      ? t('Datei auswählen', 'Izberite datoteko')
                      : t('API-Lieferung $_batch', 'API pošiljka $_batch')),
              kind: BtnKind.secondary,
              onPressed: _busy ? null : _choose,
            ),
            if (_file == null && _batch == null) ...[
              const SizedBox(height: 18),
              TextField(
                controller: _csv,
                maxLines: 5,
                decoration: InputDecoration(labelText: t('Oder CSV / TXT einfügen', 'Ali prilepite CSV / TXT')),
                onChanged: (_) => setState(_invalidate),
              ),
            ],
            if (_file != null || _batch != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _file = null;
                        _batch = null;
                        _selection.remove('sheet');
                        _selection.remove('recordPath');
                        _selection.remove('zipEntry');
                        _invalidate();
                      }),
                child: Text(t('Datei / Lieferung entfernen', 'Odstrani datoteko / pošiljko')),
              ),
            const SizedBox(height: 18),
            DataFields(
              key: ValueKey(_kind),
              value: _selection,
              fields: [
                const Input(
                  'encoding',
                  'Textkodierung',
                  'Kodiranje',
                  options: {
                    '': 'UTF-8 / BOM',
                    'windows-1252': 'Windows-1252',
                    'iso-8859-1': 'ISO-8859-1',
                    'utf-16le': 'UTF-16 LE',
                    'utf-8': 'UTF-8',
                    'utf-16be': 'UTF-16 BE',
                    'windows-1250': 'Windows-1250',
                    'iso-8859-15': 'ISO-8859-15',
                    'iso-8859-2': 'ISO-8859-2',
                    'ibm850': 'DOS 850',
                    'ibm852': 'DOS 852',
                  },
                ),
                const Input('headerRow', 'Kopfzeile (1–50)', 'Vrstica z naslovi (1–50)', kind: 'number'),
                if (_kind != 'annual') const Input('source', 'Quelle', 'Vir'),
                const Input(
                  'decimalSeparator',
                  'Dezimaltrennzeichen',
                  'Decimalno ločilo',
                  options: {'.': '60000.50', ',': '60000,50'},
                ),
              ],
              onChanged: () => setState(_invalidate),
            ),
            EqButton(
              label: t('Vorschau und Zuordnung', 'Predogled in preslikava'),
              busy: _busy,
              onPressed: () => _run(() async {
                final ledger = _kind == 'annual'
                    ? null
                    : await ref.read(apiClientProvider).getJson('/payroll?year=$year');
                final result = await ref
                    .read(apiClientProvider)
                    .postJson(_kind == 'annual' ? '/import/preview' : '/payroll/preview', _payload());
                if (!mounted) return;
                setState(() {
                  _preview = result;
                  _mapping = object(result['mapping']);
                  _quality = result['quality'] is Map ? object(result['quality']) : null;
                  _confirmed = false;
                  _ledgerVersion = ledger?['version'] as int?;
                });
              }),
            ),
            if (_preview != null) ...[
              for (final selector in [
                ('sheets', 'sheet', 'Arbeitsblatt / Delovni list'),
                ('recordPaths', 'recordPath', 'Datensatzpfad / Pot zapisov'),
                ('zipEntries', 'zipEntry', 'ZIP-Datei / Datoteka ZIP'),
              ])
                if ((_preview![selector.$1] as List? ?? []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: DropdownButtonFormField<String>(
                      initialValue: (_preview![selector.$1] as List).contains(_selection[selector.$2])
                          ? _selection[selector.$2] as String?
                          : null,
                      decoration: InputDecoration(labelText: selector.$3),
                      items: [
                        for (final option in _preview![selector.$1] as List)
                          DropdownMenuItem(value: option.toString(), child: Text(option.toString())),
                      ],
                      onChanged: (v) => setState(() {
                        _selection[selector.$2] = v;
                        _confirmed = false;
                        _quality = null;
                        _preview!['selectionRequired'] = true;
                      }),
                    ),
                  ),
              if (_preview!['selectionRequired'] == true)
                NoticeBanner(t('Auswahl treffen und Vorschau erneut öffnen.', 'Izberite in ponovno odprite predogled.'))
              else ...[
                const SizedBox(height: 24),
                SectionTitle('${_preview!['count']} · ${t('Datensätze', 'zapisov')}'),
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('$field-${_mapping[field]}'),
                      initialValue: headers.contains(_mapping[field]) ? _mapping[field].toString() : null,
                      decoration: InputDecoration(labelText: importLabels[field] ?? field),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('—')),
                        for (final h in headers)
                          DropdownMenuItem(
                            value: h,
                            child: Text(h, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                              _mapping[field] = v;
                              _quality = null;
                              _confirmed = false;
                            }),
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [for (final h in headers) DataColumn(label: Text(h))],
                    rows: [
                      for (final row in records(_preview!['rows']).take(30))
                        DataRow(cells: [for (final h in headers) DataCell(Text('${row[h] ?? ''}'))]),
                    ],
                  ),
                ),
                for (final issue in records(_preview!['contextErrors']))
                  NoticeBanner('${issue['row'] ?? ''} · ${issue['column'] ?? ''}: ${issue['error']}'),
                if (_kind == 'annual') ...[
                  DataFields(
                    value: _fixes,
                    fields: const [
                      Input('normalizeNumbers', 'Zahlenformate bereinigen', 'Počisti številske oblike', kind: 'bool'),
                      Input(
                        'emptyBonusAsZero',
                        'Leere variable Beträge als Null',
                        'Prazne variabilne zneske obravnavaj kot nič',
                        kind: 'bool',
                      ),
                    ],
                    onChanged: () => setState(() {
                      _quality = null;
                      _confirmed = false;
                    }),
                  ),
                  EqButton(
                    label: t('Datenqualität prüfen', 'Preveri kakovost podatkov'),
                    kind: BtnKind.secondary,
                    busy: _busy,
                    onPressed: () => _run(_check),
                  ),
                  for (final finding in records(_quality?['findings']))
                    entryCard(
                      context,
                      '${finding['code']}',
                      '${finding['field'] ?? ''} · ${finding['count'] ?? ''}',
                      onTap: () async {
                        await editData(
                          context,
                          title: t('Korrektur prüfen', 'Preveri popravek'),
                          fields: [
                            Input('row', 'Zeile (wie in der Prüfung)', 'Vrstica (kot v pregledu)', kind: 'number'),
                            Input('field', 'Feld', 'Polje', options: {for (final f in annualFields) f: f}),
                            Input('value', 'Korrigierter Wert', 'Popravljena vrednost'),
                          ],
                          initial: {'field': finding['field']},
                          save: (v) async {
                            _fixes['edits'] = [...(_fixes['edits'] as List? ?? []), v];
                            await _check();
                          },
                        );
                      },
                    ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await editData(
                              context,
                              title: t('Weitere Korrekturen', 'Dodatni popravki'),
                              fields: const [
                                Input('categoryFrom', 'Kategorie ersetzen', 'Zamenjaj kategorijo'),
                                Input('categoryTo', 'Neue Kategorie', 'Nova kategorija'),
                                Input('genderFrom', 'Geschlechtswert ersetzen', 'Zamenjaj spol'),
                                Input(
                                  'genderTo',
                                  'Neuer Wert',
                                  'Nova vrednost',
                                  options: {'M': 'M', 'F': 'F', 'O': 'O'},
                                ),
                                Input(
                                  'multiplyField',
                                  'Jahresbetrag multiplizieren',
                                  'Pomnoži letni znesek',
                                  options: {'base_annual': 'Grundentgelt', 'bonuses_annual': 'Variabel'},
                                ),
                                Input('factor', 'Faktor', 'Faktor', kind: 'number'),
                                Input('excludeRow', 'Zeile ausschließen', 'Izključi vrstico', kind: 'number'),
                              ],
                              save: (v) async {
                                for (final type in ['category', 'gender']) {
                                  if ('${v['${type}From'] ?? ''}'.isNotEmpty) {
                                    final map = object(_fixes['${type}Map']);
                                    map[v['${type}From'].toString()] = v['${type}To'];
                                    _fixes['${type}Map'] = map;
                                  }
                                }
                                if (v['multiplyField'] != null && v['factor'] != null) {
                                  final map = object(_fixes['multiply']);
                                  map[v['multiplyField']] = v['factor'];
                                  _fixes['multiply'] = map;
                                }
                                if (v['excludeRow'] != null) {
                                  _fixes['excludeRows'] = [...(_fixes['excludeRows'] as List? ?? []), v['excludeRow']];
                                }
                                await _check();
                              },
                            );
                          },
                    child: Text(
                      t(
                        'Kategorien, Geschlecht, Faktoren und Zeilen korrigieren',
                        'Popravi kategorije, spol, faktorje in vrstice',
                      ),
                    ),
                  ),
                  if (object(_preview!['assistant'])['available'] == true)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              if (!await confirmAction(
                                context,
                                t('KI-Assistenz', 'Pomoč umetne inteligence'),
                                t(
                                  'Die auf dem Web angegebene KI-Assistenz für diese Daten ausdrücklich verwenden?',
                                  'Želite izrecno uporabiti spletno pomoč umetne inteligence za te podatke?',
                                ),
                              )) {
                                return;
                              }
                              final result = await ref.read(apiClientProvider).postJson('/import/assist', {
                                ..._payload(),
                                'mapping': _mapping,
                                'fixes': _fixes,
                                'consent': true,
                                'language': ref.read(languageProvider),
                              });
                              if (context.mounted) setState(() => _assistant = result);
                            }),
                      child: Text(t('KI-Vorschläge anfordern', 'Pridobi predloge umetne inteligence')),
                    ),
                ],
                if (_assistant != null) ...[
                  for (final suggestion in records(_assistant!['mapping']))
                    entryCard(
                      context,
                      '${suggestion['column']} → ${suggestion['field']}',
                      '${suggestion['reason'] ?? ''}',
                      onTap: _busy
                          ? null
                          : () => _run(() async {
                              setState(() => _mapping[suggestion['field']] = suggestion['column']);
                              await _check();
                            }),
                    ),
                  for (final suggestion in records(_assistant!['categories']))
                    entryCard(
                      context,
                      '${suggestion['from']} → ${suggestion['to']}',
                      '${suggestion['reason'] ?? ''}',
                      onTap: _busy
                          ? null
                          : () => _run(() async {
                              final categories = object(_fixes['categoryMap']);
                              for (final name in suggestion['from'] as List? ?? []) {
                                categories[name.toString()] = suggestion['to'];
                              }
                              _fixes['categoryMap'] = categories;
                              await _check();
                            }),
                    ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t(
                      'Hinweise geprüft; Zuordnung, EUR, Zeitraum und bezahlte Stunden bestätigen.',
                      'Opozorila pregledana; potrdite preslikavo, EUR, obdobje in plačane ure.',
                    ),
                  ),
                  value: _confirmed,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _confirmed = v == true;
                          _warnings = v == true;
                        }),
                ),
                EqButton(
                  label: _kind == 'annual'
                      ? t('Jahresdaten importieren', 'Uvozi letne podatke')
                      : t('Monatliche Daten übernehmen', 'Dodaj mesečne podatke'),
                  busy: _busy,
                  onPressed:
                      !_confirmed ||
                          (_kind == 'annual' &&
                              (_quality == null ||
                                  (object(_quality!['summary'])['errors'] as num? ?? 0) > 0 ||
                                  !_warnings))
                      ? null
                      : () => _run(() async {
                          final api = ref.read(apiClientProvider);
                          await api.postJson(_kind == 'annual' ? '/import' : '/payroll/stage', {
                            ..._payload(),
                            'mapping': _mapping,
                            'fixes': _fixes,
                            'contextConfirmed': true,
                            if (_kind != 'annual') 'version': _ledgerVersion,
                          });
                          ref.invalidate(payAnalysisProvider);
                          ref.invalidate(payReadinessProvider);
                          if (context.mounted) {
                            setState(() {
                              _file = null;
                              _csv.clear();
                              _invalidate();
                            });
                            showSnack(context, t('Daten übernommen.', 'Podatki so dodani.'));
                          }
                        }),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
