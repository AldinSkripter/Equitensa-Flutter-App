import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/ui.dart';
import '../pay/pay_modules.dart' show payAction, spaced;
import '../workspace/workspace_widgets.dart';
import 'document_style.dart';

const productFields = [
  Input('name', 'Artikel / Leistung', 'Artikel / storitev', required: true),
  Input('sku', 'Artikelnummer', 'Šifra artikla'),
  Input('unit', 'Einheit', 'Enota'),
  Input('unitPrice', 'Nettopreis EUR', 'Neto cena EUR', required: true),
  Input('rate', 'Umsatzsteuer %', 'DDV %', required: true),
  Input('archived', 'Archiviert', 'Arhivirano', kind: 'bool'),
];
const expenseFields = [
  Input('supplier', 'Lieferant', 'Dobavitelj', required: true),
  Input('reference', 'Belegnummer', 'Številka dokumenta', required: true),
  Input('incurredOn', 'Belegdatum (YYYY-MM-DD)', 'Datum dokumenta', kind: 'date', required: true),
  Input('amount', 'Bruttobetrag EUR', 'Bruto znesek EUR', required: true),
  Input(
    'category',
    'Kategorie',
    'Kategorija',
    options: {
      'software': 'Software',
      'office': 'Büro / Pisarna',
      'travel': 'Reisen / Potovanja',
      'services': 'Dienstleistungen / Storitve',
      'other': 'Sonstiges / Drugo',
    },
  ),
  Input('note', 'Notiz', 'Opomba', kind: 'long'),
];

class FinanceModuleScreen extends ConsumerWidget {
  const FinanceModuleScreen({super.key, required this.module, this.id});
  final String module;
  final String? id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref), fmt = fmtOf(ref);
    final names = {
      'products': t('Artikel & Leistungen', 'Artikli in storitve'),
      'bank': t('Bankabgleich', 'Bančna uskladitev'),
      'recurring': t('Serienrechnungen', 'Ponavljajoči se računi'),
      'receivables': t('Offene Forderungen', 'Odprte terjatve'),
      'exports': t('Exporte & Aktivitäten', 'Izvozi in aktivnosti'),
      'designs': t('Designbibliothek', 'Knjižnica izgledov'),
      'documents': t('Dokumente', 'Dokumenti'),
      'actions': t('Dokument verwalten', 'Upravljanje dokumenta'),
      'expense': t('Ausgabe & Belege', 'Strošek in dokumenti'),
    };
    return RemotePage(
      title: names[module] ?? module,
      load: (ref) async {
        final api = ref.read(apiClientProvider);
        final responses = await Future.wait([
          api.getJson('/finance'),
          if (module == 'receivables') api.getJson('/finance/receivables'),
        ]);
        return {...responses.first, if (responses.length > 1) 'receivables': responses[1]};
      },
      builder: (context, ref, data, reload) {
        final state = object(data['state']), docs = records(state['documents']);
        final api = ref.read(apiClientProvider);
        Future<Data> mutate(String path, Data value) async {
          final result = await ref.read(repositoryProvider).financeAction(path, state['revision'] as int, value);
          ref.read(financeProvider.notifier).apply(result.state);
          return result.result;
        }

        Future<void> edit(String title, List<Input> fields, Data initial, String path) async {
          final saved = await editData(
            context,
            title: title,
            fields: fields,
            initial: initial,
            save: (v) async {
              await mutate(path, v);
            },
          );
          if (saved != null) reload();
        }

        Widget button(String label, Future<void> Function() action) =>
            spaced(AsyncAction(label: label, action: action));
        List<Widget> children;
        switch (module) {
          case 'products':
            children = [
              button(
                t('Artikel hinzufügen', 'Dodaj artikel'),
                () => edit(t('Neuer Artikel', 'Nov artikel'), productFields, {
                  'unit': 'h',
                  'rate': ref.read(countryProvider).code == 'DE'
                      ? '19'
                      : ref.read(countryProvider).code == 'AT'
                      ? '20'
                      : '22',
                }, 'products'),
              ),
              for (final product in records(state['products']))
                entryCard(
                  context,
                  '${product['name']}${product['archived'] == true ? ' · ${t('Archiviert', 'Arhivirano')}' : ''}',
                  '${product['sku']} · ${product['unitPrice']} EUR / ${product['unit']} · ${product['rate']} %',
                  onTap: () => edit('${product['name']}', productFields, product, 'products/${product['id']}'),
                  trailing: product['archived'] == true
                      ? null
                      : IconButton(
                          tooltip: t('In Dokument verwenden', 'Uporabi v dokumentu'),
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => context.push('/finance/compose?kind=invoice&product=${product['id']}'),
                        ),
                ),
            ];
          case 'bank':
            children = [
              NoticeBanner(
                t(
                  'CSV-Abgleich mit manuell bestätigter Zuordnung. Keine automatische Bankverbindung.',
                  'Uskladitev CSV z ročno potrjeno povezavo. Brez samodejne bančne povezave.',
                ),
              ),
              const SizedBox(height: 16),
              button(t('Bank-CSV importieren', 'Uvozi bančni CSV'), () async {
                final selected = await pickDocument();
                if (selected == null || !context.mounted) return;
                if (selected.bytes.length > 1000000) throw StateError('Maximal 1 MB');
                final input = {
                  'csv': utf8.decode(selected.bytes),
                  'delimiter': ';',
                  'account': object(state['profile'])['iban'],
                  'mapping': <String, dynamic>{},
                };
                final result = await editData(
                  context,
                  title: t('Bankspalten zuordnen', 'Preslikaj bančne stolpce'),
                  initial: input,
                  fields: const [
                    Input('account', 'Bankkonto / Kennung', 'Bančni račun / oznaka', required: true),
                    Input('delimiter', 'Trennzeichen', 'Ločilo', options: {';': ';', ',': ',', '\t': 'Tab'}),
                    Input(
                      'mapping.externalId',
                      'Spalte: eindeutige Buchungs-ID',
                      'Stolpec: enolična šifra transakcije',
                      required: true,
                    ),
                    Input(
                      'mapping.bookedOn',
                      'Spalte: Buchungstag YYYY-MM-DD',
                      'Stolpec: datum YYYY-MM-DD',
                      required: true,
                    ),
                    Input('mapping.amount', 'Spalte: Betrag EUR', 'Stolpec: znesek EUR', required: true),
                    Input('mapping.description', 'Spalte: Beschreibung', 'Stolpec: opis', required: true),
                  ],
                  action: t('Prüfen', 'Preveri'),
                  save: (v) async {
                    final preview = await api.postJson('/finance/bank/preview', v);
                    if (!context.mounted) return;
                    final rows = records(preview['transactions']);
                    if (!await confirmAction(
                      context,
                      t('Bankimport bestätigen', 'Potrdi bančni uvoz'),
                      '${rows.length} ${t('Buchungen', 'transakcij')}\n${rows.take(5).map((r) => '${r['bookedOn']} · ${fmt.money((r['amountCents'] as num).toInt())} · ${r['description']}').join('\n')}',
                    )) {
                      return;
                    }
                    await mutate('bank/import', v);
                  },
                );
                if (result != null) reload();
              }),
              for (final transaction in records(state['bankTransactions']))
                entryCard(
                  context,
                  '${transaction['description']}',
                  '${transaction['bookedOn']} · ${fmt.money((transaction['amountCents'] as num).toInt())}',
                  onTap: (transaction['amountCents'] as num) > 0
                      ? () => edit(
                          t('Zahlung zuordnen', 'Poveži plačilo'),
                          [
                            Input(
                              'documentId',
                              'Rechnung',
                              'Račun',
                              options: {
                                for (final d in docs.where((d) => d['kind'] == 'invoice' && d['status'] == 'issued'))
                                  d['id'].toString(): '${d['number']} · ${object(d['customer'])['name']}',
                              },
                            ),
                            const Input('amount', 'Betrag EUR', 'Znesek EUR', required: true),
                            const Input(
                              'confirm',
                              'Zuordnung geprüft und bestätigt',
                              'Povezava preverjena in potrjena',
                              kind: 'bool',
                            ),
                          ],
                          {'amount': ((transaction['amountCents'] as num) / 100).toStringAsFixed(2)},
                          'bank/${transaction['id']}/allocate',
                        )
                      : null,
                ),
            ];
          case 'recurring':
            children = [
              NoticeBanner(
                t(
                  'Serien erzeugen ausschließlich Entwürfe. Ausstellung und Versand werden separat bestätigt.',
                  'Serije ustvarijo samo osnutke. Izdaja in pošiljanje se potrdita ločeno.',
                ),
              ),
              const SizedBox(height: 16),
              button(
                t('Serie anlegen', 'Dodaj serijo'),
                () => edit(
                  t('Neue Serie', 'Nova serija'),
                  [
                    const Input('name', 'Bezeichnung', 'Naziv', required: true),
                    Input(
                      'documentId',
                      'Rechnung als Vorlage',
                      'Račun kot predloga',
                      options: {
                        for (final d in docs.where((d) => d['kind'] == 'invoice'))
                          d['id'].toString():
                              '${d['number'] ?? t('Entwurf', 'Osnutek')} · ${object(d['customer'])['name']}',
                      },
                    ),
                    const Input('startDate', 'Beginn (YYYY-MM-DD)', 'Začetek', kind: 'date'),
                    const Input(
                      'interval',
                      'Intervall',
                      'Interval',
                      options: {
                        '1': 'Monatlich / Mesečno',
                        '3': 'Quartalsweise / Četrtletno',
                        '12': 'Jährlich / Letno',
                      },
                    ),
                    const Input(
                      'paymentDays',
                      'Zahlungsfrist in Tagen (0–90)',
                      'Rok plačila v dnevih (0–90)',
                      kind: 'number',
                    ),
                    const Input(
                      'autoOnOpen',
                      'Bei Öffnung fällige Entwürfe erzeugen',
                      'Ob odprtju ustvari zapadle osnutke',
                      kind: 'bool',
                    ),
                  ],
                  {'startDate': Fmt.today(), 'interval': '1', 'paymentDays': 14},
                  'recurring',
                ),
              ),
              button(t('Fällige Entwürfe erzeugen', 'Ustvari zapadle osnutke'), () async {
                if (!await confirmAction(
                  context,
                  t('Entwürfe erzeugen', 'Ustvari osnutke'),
                  t('Fällige Serienperioden jetzt verarbeiten?', 'Obdelate zapadla obdobja serij?'),
                )) {
                  return;
                }
                await mutate('recurring/run', {});
                reload();
              }),
              for (final series in records(state['recurring']))
                entryCard(
                  context,
                  '${series['name']}',
                  '${series['nextDate']} · ${series['interval']} ${t('Monate', 'mesecev')} · ${series['paused'] == true ? t('Pausiert', 'Začasno ustavljeno') : t('Aktiv', 'Aktivno')}',
                  onTap: () => payAction(context, () async {
                    if (!await confirmAction(
                      context,
                      t('Serienstatus ändern', 'Spremeni stanje serije'),
                      '${series['name']}',
                    )) {
                      return;
                    }
                    await mutate('recurring/${series['id']}/toggle', {});
                    reload();
                  }),
                ),
            ];
          case 'receivables':
            final receivables = object(data['receivables']);
            children = [
              button(
                t('Forderungen als CSV', 'Terjatve kot CSV'),
                () => downloadFile(context, ref, '/finance/receivables.csv', 'equitensa-receivables.csv'),
              ),
              for (final e in receivables.entries.where((e) => e.value is num))
                entryCard(context, e.key, fmt.money((e.value as num).toInt())),
              for (final d in docs.where(
                (d) =>
                    d['kind'] == 'invoice' &&
                    d['status'] == 'issued' &&
                    (d['grossCents'] as num) >
                        records(d['payments']).fold<num>(0, (v, p) => v + (p['amountCents'] as num)),
              ))
                entryCard(
                  context,
                  '${d['number']}',
                  '${object(d['customer'])['name']} · ${d['dueDate']} · ${fmt.money((d['grossCents'] as num).toInt())}',
                  onTap: () => context.push('/finance/document/${d['id']}'),
                ),
            ];
          case 'style':
            final profile = object(state['profile']);
            final design = object(profile['design']);
            children = [
              button(
                t('Design-Einstellungen bearbeiten', 'Uredi nastavitve izgleda'),
                () => edit(t('Dokumentdesign', 'Izgled dokumenta'), documentStyleFields, {
                  ...profile,
                  'country': state['country'],
                  'confirmCountry': true,
                }, 'settings'),
              ),
              button(t('Textblock hinzufügen', 'Dodaj besedilni blok'), () async {
                if (records(design['blocks']).length >= 8) throw StateError('Maximal 8 Textblöcke');
                await editData(
                  context,
                  title: t('Neuer Textblock', 'Nov besedilni blok'),
                  fields: const [
                    Input('heading', 'Überschrift', 'Naslov'),
                    Input('body', 'Text', 'Besedilo', kind: 'long'),
                    Input(
                      'position',
                      'Position',
                      'Položaj',
                      options: {
                        'intro': 'Einleitung / Uvod',
                        'afterItems': 'Nach Positionen / Za postavkami',
                        'closing': 'Abschluss / Zaključek',
                      },
                    ),
                  ],
                  initial: {'position': 'closing'},
                  save: (v) async {
                    final next = copyData(profile);
                    next['design'] = {
                      ...design,
                      'blocks': [...records(design['blocks']), v],
                    };
                    await mutate('settings', {...next, 'country': state['country'], 'confirmCountry': true});
                  },
                );
                reload();
              }),
              for (var i = 0; i < records(design['blocks']).length; i++)
                entryCard(
                  context,
                  '${records(design['blocks'])[i]['heading'] ?? ''}',
                  '${records(design['blocks'])[i]['position']}',
                  onTap: () async {
                    final result = await editData(
                      context,
                      title: t('Textblock', 'Besedilni blok'),
                      initial: records(design['blocks'])[i],
                      fields: const [
                        Input('heading', 'Überschrift', 'Naslov'),
                        Input('body', 'Text', 'Besedilo', kind: 'long'),
                        Input(
                          'position',
                          'Position',
                          'Položaj',
                          options: {
                            'intro': 'Einleitung / Uvod',
                            'afterItems': 'Nach Positionen / Za postavkami',
                            'closing': 'Abschluss / Zaključek',
                          },
                        ),
                        Input('remove', 'Entfernen', 'Odstrani', kind: 'bool'),
                      ],
                      save: (v) async {
                        final blocks = records(design['blocks']);
                        if (v['remove'] == true) {
                          blocks.removeAt(i);
                        } else {
                          blocks[i] = v;
                        }
                        await mutate('settings', {
                          ...profile,
                          'country': state['country'],
                          'confirmCountry': true,
                          'design': {...design, 'blocks': blocks},
                        });
                      },
                    );
                    if (result != null) reload();
                  },
                ),
            ];
          case 'designs':
            final profile = object(state['profile']);
            children = [
              entryCard(
                context,
                t('Erweitertes Designstudio', 'Napredni studio izgleda'),
                '',
                onTap: () => context.push('/finance/style'),
              ),
              entryCard(
                context,
                t('Firmen-Design bearbeiten', 'Uredi izgled podjetja'),
                t('Vorlage, Schrift, Farben und Logo', 'Predloga, pisava, barve in logotip'),
                onTap: () => context.push('/finance/company'),
              ),
              button(
                t('Aktuelles Design in Bibliothek speichern', 'Shrani trenutni izgled v knjižnico'),
                () => edit(
                  t('Design speichern', 'Shrani izgled'),
                  const [Input('name', 'Designname', 'Ime izgleda', required: true)],
                  {
                    'appearance': {'accent': profile['accent'], 'design': profile['design']},
                  },
                  'designs',
                ),
              ),
              for (final design in records(state['designs']))
                entryCard(
                  context,
                  '${design['name']}',
                  '${object(object(design['appearance'])['design'])['template']}',
                  onTap: () => payAction(context, () async {
                    if (!await confirmAction(
                      context,
                      t('Als Firmendesign verwenden', 'Uporabi kot izgled podjetja'),
                      '${design['name']}',
                    )) {
                      return;
                    }
                    await mutate('settings', {
                      ...profile,
                      'country': state['country'],
                      'confirmCountry': true,
                      ...object(design['appearance']),
                    });
                    reload();
                  }),
                  trailing: IconButton(
                    tooltip: t('Entfernen', 'Odstrani'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => payAction(context, () async {
                      if (!await confirmAction(
                        context,
                        t('Design entfernen', 'Odstrani izgled'),
                        '${design['name']}',
                      )) {
                        return;
                      }
                      await mutate('designs/${design['id']}/remove', {});
                      reload();
                    }),
                  ),
                ),
            ];
          case 'expense':
            final expense = records(state['expenses']).where((e) => e['id'] == id).firstOrNull;
            if (expense == null) {
              children = [Text(t('Nicht gefunden', 'Ni najdeno'))];
              break;
            }
            children = [
              entryCard(
                context,
                '${expense['supplier']}',
                '${expense['reference']} · ${expense['incurredOn']} · ${fmt.money((expense['amountCents'] as num).toInt())}',
              ),
              button(
                t('Ausgabe bearbeiten', 'Uredi strošek'),
                () => edit(t('Ausgabe bearbeiten', 'Uredi strošek'), expenseFields, {
                  ...expense,
                  'amount': ((expense['amountCents'] as num) / 100).toStringAsFixed(2),
                }, 'expenses/$id'),
              ),
              button(t('Originalbeleg hinzufügen', 'Dodaj izvirni dokument'), () async {
                final file = await pickDocument();
                if (file == null) return;
                if (!context.mounted ||
                    !await confirmAction(
                      context,
                      t('Originalbeleg speichern', 'Shrani izvirni dokument'),
                      file.name,
                    )) {
                  return;
                }
                await mutate('expenses/$id/attachments', {'filename': file.name, 'data': base64Encode(file.bytes)});
                reload();
              }),
              for (final file in records(state['attachments']).where((f) => f['expenseId'] == id))
                entryCard(
                  context,
                  '${file['filename']}',
                  '${file['uploadedAt']}',
                  onTap: () => downloadFile(context, ref, '/finance/attachments/${file['id']}', '${file['filename']}'),
                ),
            ];
          case 'actions':
            final doc = docs.where((d) => d['id'] == id).firstOrNull;
            if (doc == null) {
              children = [Text(t('Nicht gefunden', 'Ni najdeno'))];
              break;
            }
            final share = object(doc['share']);
            children = [
              entryCard(context, '${doc['number'] ?? t('Entwurf', 'Osnutek')}', '${object(doc['customer'])['name']}'),
              if (doc['kind'] == 'offer')
                button(
                  t('Angebotsstatus dokumentieren', 'Zabeleži stanje ponudbe'),
                  () => edit(
                    t('Angebotsstatus', 'Stanje ponudbe'),
                    const [
                      Input(
                        'status',
                        'Neuer Status',
                        'Novo stanje',
                        options: {
                          'prepared': 'Vorbereitet / Pripravljeno',
                          'sent': 'Extern versandt / Poslano zunaj aplikacije',
                          'accepted': 'Angenommen / Sprejeto',
                          'rejected': 'Abgelehnt / Zavrnjeno',
                        },
                      ),
                      Input(
                        'validUntil',
                        'Gültig bis (YYYY-MM-DD, beim Versand erforderlich)',
                        'Velja do (pri pošiljanju obvezno)',
                        kind: 'date',
                      ),
                      Input('note', 'Notiz / Nachweis', 'Opomba / dokazilo', kind: 'long'),
                    ],
                    {'note': ''},
                    'documents/$id/offer-status',
                  ),
                ),
              button(t('Befristeten Freigabelink erstellen', 'Ustvari časovno omejeno povezavo'), () async {
                final result = await editData(
                  context,
                  title: t('Freigabelink', 'Povezava za deljenje'),
                  initial: {'enabled': true, 'days': '7'},
                  fields: const [
                    Input(
                      'days',
                      'Gültigkeit',
                      'Veljavnost',
                      options: {'7': '7 Tage / dni', '30': '30 Tage / dni', '90': '90 Tage / dni'},
                    ),
                  ],
                  save: (v) async {
                    v['days'] = int.parse(v['days'].toString());
                    final link = await mutate('documents/$id/share', v);
                    if (context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(t('Freigabelink', 'Povezava za deljenje')),
                          content: SelectableText('${link['url']}\n${link['expiresAt']}'),
                          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
                        ),
                      );
                    }
                  },
                );
                if (result != null) reload();
              }),
              if (share['url'] != null) ...[
                SelectableText('${share['url']}\n${share['expiresAt']}'),
                const SizedBox(height: 14),
                button(t('Freigabelink widerrufen', 'Prekliči povezavo'), () async {
                  if (!await confirmAction(
                    context,
                    t('Freigabe widerrufen', 'Prekliči deljenje'),
                    '${doc['number'] ?? id}',
                  )) {
                    return;
                  }
                  await mutate('documents/$id/share', {'enabled': false});
                  reload();
                }),
              ],
              if (doc['kind'] == 'invoice' && doc['status'] == 'issued') ...[
                button(
                  t('Originalpaket ZIP herunterladen', 'Prenesi izvirni paket ZIP'),
                  () => downloadFile(context, ref, '/finance/documents/$id/bundle.zip', '${doc['number']}.zip'),
                ),
                for (final file in records(doc['originals']))
                  button(
                    '${file['filename']}',
                    () => downloadFile(
                      context,
                      ref,
                      '/finance/documents/$id/originals/${Uri.encodeComponent(file['id'].toString())}',
                      '${file['filename']}',
                    ),
                  ),
                button(t('E-Mail-Entwurf mit Originalen', 'Osnutek e-pošte z izvirniki'), () async {
                  await editData(
                    context,
                    title: t('E-Mail-Entwurf', 'Osnutek e-pošte'),
                    fields: const [
                      Input('recipient', 'Empfänger-E-Mail', 'E-pošta prejemnika', required: true),
                      Input('subject', 'Betreff', 'Zadeva'),
                      Input('message', 'Nachricht', 'Sporočilo', kind: 'long'),
                    ],
                    initial: {'recipient': object(doc['customer'])['email']},
                    action: t('EML herunterladen', 'Prenesi EML'),
                    save: (v) => downloadFile(
                      context,
                      ref,
                      '/finance/documents/$id/email-draft',
                      '${doc['number']}.eml',
                      body: {
                        for (final e in v.entries)
                          if (e.value != null && e.value != '') e.key: e.value,
                      },
                    ),
                  );
                }),
                button(
                  t('Zahlungserinnerung als Entwurf', 'Opomin kot osnutek'),
                  () => downloadFile(
                    context,
                    ref,
                    '/finance/documents/$id/reminder.eml',
                    '${doc['number']}-reminder.eml',
                  ),
                ),
                button(
                  t('Externen Versand dokumentieren', 'Zabeleži zunanje pošiljanje'),
                  () => edit(
                    t('Versandnachweis', 'Dokazilo o pošiljanju'),
                    const [
                      Input(
                        'channel',
                        'Kanal',
                        'Kanal',
                        options: {'email': 'E-Mail', 'portal': 'Portal', 'other': 'Sonstiges / Drugo'},
                      ),
                      Input('recipient', 'Empfänger-E-Mail', 'E-pošta prejemnika', required: true),
                      Input('sentAt', 'Versandzeit ISO (YYYY-MM-DDTHH:MM:SSZ)', 'Čas pošiljanja ISO', required: true),
                      Input('reference', 'Nachweis / Referenz', 'Dokazilo / referenca', required: true),
                      Input('confirm', 'Externen Versand bestätigen', 'Potrdi zunanje pošiljanje', kind: 'bool'),
                    ],
                    {
                      'channel': 'email',
                      'recipient': object(doc['customer'])['email'],
                      'sentAt': DateTime.now().toUtc().toIso8601String(),
                    },
                    'documents/$id/delivery',
                  ),
                ),
                for (final delivery in records(doc['deliveries']))
                  entryCard(
                    context,
                    '${delivery['channel']} · ${delivery['recipient']}',
                    '${delivery['sentAt']} · ${delivery['reference']}',
                  ),
              ],
            ];
          case 'documents':
            children = [
              entryCard(
                context,
                t('Alle Rechnungen & Angebote', 'Vsi računi in ponudbe'),
                '',
                onTap: () => context.push('/finance/sales'),
              ),
              entryCard(
                context,
                t('Belege & Ausgaben', 'Dokumenti in stroški'),
                '',
                onTap: () => context.push('/finance/expenses'),
              ),
              for (final file in records(state['attachments']))
                entryCard(
                  context,
                  '${file['filename']}',
                  '${file['uploadedAt']}',
                  onTap: () => downloadFile(context, ref, '/finance/attachments/${file['id']}', '${file['filename']}'),
                ),
              for (final doc in docs.where((d) => records(d['originals']).isNotEmpty))
                entryCard(
                  context,
                  '${doc['number']}',
                  '${records(doc['originals']).length} ${t('Originale', 'izvirnikov')}',
                  onTap: () => context.push('/finance/manage-document/${doc['id']}'),
                ),
            ];
          default:
            children = [
              button(t('CSV herunterladen', 'Prenesi CSV'), () async {
                await editData(
                  context,
                  title: t('CSV-Export', 'Izvoz CSV'),
                  initial: {'kind': 'documents', 'year': ''},
                  fields: const [
                    Input(
                      'kind',
                      'Daten',
                      'Podatki',
                      options: {
                        'documents': 'Dokumente / Dokumenti',
                        'payments': 'Zahlungen / Plačila',
                        'expenses': 'Ausgaben / Stroški',
                        'contacts': 'Kontakte / Stiki',
                        'products': 'Artikel / Artikli',
                      },
                    ),
                    Input('year', 'Jahr (leer = alle)', 'Leto (prazno = vsa)'),
                  ],
                  action: t('Herunterladen', 'Prenesi'),
                  save: (v) => downloadFile(
                    context,
                    ref,
                    '/finance/export.csv?${Uri(queryParameters: {'kind': v['kind'], if ('${v['year'] ?? ''}'.isNotEmpty) 'year': v['year']}).query}',
                    'finance-${v['kind']}.csv',
                  ),
                );
              }),
              button(
                t('Alle Daten als JSON', 'Vsi podatki kot JSON'),
                () => downloadFile(context, ref, '/finance/export', 'equitensa-finance.json'),
              ),
              button(
                t('Daten und Originale als ZIP', 'Podatki in izvirniki kot ZIP'),
                () => downloadFile(context, ref, '/finance/archive.zip', 'equitensa-finance-backup.zip'),
              ),
              SectionTitle(t('Aktivitäten', 'Aktivnosti')),
              for (final event in records(state['events']).reversed.take(50))
                entryCard(context, '${event['action']}', '${event['at']}'),
            ];
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      },
    );
  }
}
