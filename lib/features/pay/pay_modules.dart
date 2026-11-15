import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../workspace/workspace_widgets.dart';

Future<void> payAction(BuildContext context, Future<void> Function() work) async {
  try {
    await work();
  } catch (e) {
    if (context.mounted) showApiError(context, e);
  }
}

Widget spaced(Widget child) => Padding(padding: const EdgeInsets.only(bottom: 16), child: child);

class PayModuleScreen extends ConsumerWidget {
  const PayModuleScreen({super.key, required this.module});
  final String module;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final names = {
      'exports': t('Berichte & Exporte', 'Poročila in izvozi'),
      'rights': t('Auskunftsrechte', 'Pravice do informacij'),
      'criteria': t('Entgeltkriterien', 'Merila za plače'),
      'obligations': t('Arbeitgebernachweise', 'Dokazila delodajalca'),
      'national': t('Nationaler Bericht', 'Nacionalno poročilo'),
      'payroll': t('Monatliche Abrechnung', 'Mesečni obračun'),
      'integrations': t('Daten & Integrationen', 'Podatki in povezave'),
      'retention': t('Datenschutz & Aufbewahrung', 'Zasebnost in hramba'),
      'billing': t('Paket & Abrechnung', 'Paket in obračun'),
    };
    return RemotePage(
      title: names[module] ?? module,
      load: (ref) async {
        final api = ref.read(apiClientProvider), y = ref.read(payYearProvider);
        final paths = switch (module) {
          'rights' => ['/requests', '/rights-notice?year=$y'],
          'criteria' => ['/pay-criteria?year=$y'],
          'obligations' => ['/employer-controls?year=$y'],
          'national' => ['/national-report?year=$y'],
          'payroll' => ['/payroll?year=$y'],
          'integrations' => ['/integrations', '/integrations/keys', '/integrations/batches', '/import/history?year=$y'],
          'retention' => ['/data-retention?year=$y', '/data-retention/receipts'],
          'billing' => ['/billing'],
          _ => ['/workflow?year=$y', '/reporting-plan?year=$y&audience=internal'],
        };
        final results = await Future.wait(paths.map(api.getJson));
        return {'items': results, 'year': y};
      },
      builder: (context, ref, loaded, reload) {
        final items = records(loaded['items']), d = items.first, year = loaded['year'];
        final api = ref.read(apiClientProvider);
        Future<void> edit(
          String title,
          List<Input> fields,
          Data initial,
          String endpoint, {
          String? envelope,
          Data extra = const {},
        }) async {
          final result = await editData(
            context,
            title: title,
            fields: fields,
            initial: initial,
            save: (value) async {
              await api.postJson(endpoint, {
                'year': year,
                ...extra,
                if (envelope != null) envelope: value else ...value,
              });
            },
          );
          if (result != null) reload();
        }

        Widget button(String label, Future<void> Function() action) =>
            spaced(AsyncAction(label: label, action: action));
        Widget formats(String title, String endpoint, Data body) => entryCard(
          context,
          title,
          'PDF · TXT · HTML',
          onTap: () async {
            await editData(
              context,
              title: title,
              initial: {'format': 'pdf'},
              fields: [
                const Input('format', 'Format', 'Oblika', options: {'pdf': 'PDF', 'txt': 'TXT', 'html': 'HTML'}),
                if (body['kind'] == 'vacancy') Input('categories', 'Kategorien (leer = alle)', 'Kategorije (prazno = vse)', kind: 'list', options: {for (final key in object(object(d['document'])['ranges']).keys) key: key}),
              ],
              action: t('Herunterladen', 'Prenesi'),
              save: (v) =>
                  downloadFile(context, ref, endpoint, 'equitensa-$module-$year.${v['format']}', body: {...body, ...v}),
            );
          },
        );
        List<Widget> content;
        switch (module) {
          case 'rights':
            final notice = object(items[1]['notice']);
            content = [
              button(
                t('Anfrage erfassen', 'Dodaj zahtevo'),
                () => edit(
                  t('Neue Anfrage', 'Nova zahteva'),
                  const [
                    Input('requesterLabel', 'Anfragende Person / Stelle', 'Prosilec', required: true),
                    Input(
                      'receivedOn',
                      'Eingegangen am (YYYY-MM-DD)',
                      'Prejeto dne (YYYY-MM-DD)',
                      kind: 'date',
                      required: true,
                    ),
                    Input(
                      'channel',
                      'Kanal',
                      'Kanal',
                      options: {
                        'worker': 'Beschäftigte / Zaposleni',
                        'representative': 'Vertretung / Predstavniki',
                        'equality_body': 'Gleichbehandlungsstelle / Organ za enakost',
                        'labour_inspectorate': 'Arbeitsaufsicht / Inšpektorat',
                      },
                    ),
                    Input(
                      'kind',
                      'Anfragetyp',
                      'Vrsta zahteve',
                      options: {
                        'information': 'Entgeltinformation / Informacije o plači',
                        'clarification': 'Klarstellung / Pojasnilo',
                      },
                    ),
                    Input('note', 'Notiz', 'Opomba', kind: 'long'),
                  ],
                  {'receivedOn': Fmt.today(), 'channel': 'worker', 'kind': 'information'},
                  '/requests',
                ),
              ),
              for (final request in records(d['requests']))
                entryCard(
                  context,
                  '${request['requester_label']}',
                  '${request['state']} · ${request['due_on']}',
                  onTap: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: context.eq.surface,
                      useSafeArea: true,
                      builder: (c) => ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            '${request['requester_label']}',
                            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 20),
                          Text('${request['note'] ?? ''}'),
                          const SizedBox(height: 20),
                          EqButton(
                            label: t('Antwortdokument erstellen', 'Ustvari odgovor'),
                            onPressed: () {
                              Navigator.pop(c);
                              editData(
                                context,
                                title: t('Antwort erstellen', 'Ustvari odgovor'),
                                fields: const [
                                  Input(
                                    'internalId',
                                    'Interne Personalnummer (nicht gespeichert)',
                                    'Interna šifra zaposlenega (se ne shrani)',
                                    required: true,
                                  ),
                                  Input(
                                    'format',
                                    'Format',
                                    'Oblika',
                                    options: {'pdf': 'PDF', 'txt': 'TXT', 'html': 'HTML', 'json': 'JSON'},
                                  ),
                                ],
                                initial: {'format': 'pdf'},
                                action: t('Erstellen', 'Ustvari'),
                                save: (v) => downloadFile(
                                  context,
                                  ref,
                                  '/requests/${request['id']}/answer',
                                  'equitensa-answer-$year.${v['format']}',
                                  body: {'year': year, ...v},
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          EqButton(
                            label: t('Antwortversand dokumentieren', 'Zabeleži poslani odgovor'),
                            kind: BtnKind.secondary,
                            onPressed: () {
                              Navigator.pop(c);
                              edit(
                                t('Versand dokumentieren', 'Zabeleži pošiljanje'),
                                const [
                                  Input('answeredOn', 'Beantwortet am (YYYY-MM-DD)', 'Odgovorjeno dne', kind: 'date'),
                                  Input('summary', 'Zusammenfassung / Beleg', 'Povzetek / dokazilo', kind: 'long'),
                                ],
                                {'answeredOn': Fmt.today()},
                                '/requests/${request['id']}/close',
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              SectionTitle(t('Jährliche Information', 'Letno obvestilo')),
              entryCard(
                context,
                t('Information an alle Beschäftigten', 'Obvestilo vsem zaposlenim'),
                '${notice['contact'] ?? ''} · ${notice['sent_on'] ?? ''}',
                onTap: () => edit(
                  t('Jährliche Information', 'Letno obvestilo'),
                  const [
                    Input('contact', 'Kontaktstelle', 'Kontakt', required: true),
                    Input('sentOn', 'Gesendet am (YYYY-MM-DD)', 'Poslano dne', kind: 'date', required: true),
                  ],
                  {'contact': notice['contact'], 'sentOn': notice['sent_on'] ?? Fmt.today()},
                  '/rights-notice',
                ),
              ),
              button(t('Informationsvorlage herunterladen', 'Prenesi predlogo obvestila'), () async {
                await editData(
                  context,
                  title: t('Informationsvorlage', 'Predloga obvestila'),
                  fields: const [
                    Input('contact', 'Kontaktstelle', 'Kontakt', required: true),
                    Input('format', 'Format', 'Oblika', options: {'pdf': 'PDF', 'txt': 'TXT', 'html': 'HTML'}),
                  ],
                  initial: {'contact': notice['contact'], 'format': 'pdf'},
                  save: (v) => downloadFile(
                    context,
                    ref,
                    '/rights-notice/document',
                    'equitensa-notice-$year.${v['format']}',
                    body: {'year': year, ...v},
                  ),
                );
              }),
            ];
          case 'criteria':
            final document = object(d['document']),
                ranges = object(document['ranges']),
                suggestions = object(d['suggestions']);
            content = [
              NoticeBanner(
                t(
                  'Entgeltbänder werden vom Arbeitgeber auf objektiven Kriterien festgelegt. Vorschläge sind keine automatische Entscheidung.',
                  'Plačilne razpone določi delodajalec po objektivnih merilih. Predlogi niso samodejna odločitev.',
                ),
              ),
              const SizedBox(height: 18),
              button(t('Entgeltband hinzufügen', 'Dodaj plačilni razpon'), () async {
                await editData(
                  context,
                  title: t('Entgeltband', 'Plačilni razpon'),
                  fields: const [
                    Input('category', 'Kategorie', 'Kategorija', required: true),
                    Input('min', 'Minimum EUR / Jahr', 'Najmanj EUR / leto', kind: 'number', required: true),
                    Input('max', 'Maximum EUR / Jahr', 'Največ EUR / leto', kind: 'number', required: true),
                    Input('agreement', 'Kollektivvertrag', 'Kolektivna pogodba'),
                  ],
                  save: (v) async {
                    final next = copyData(document);
                    final r = object(next['ranges']);
                    r[v['category']] = {'min': v['min'], 'max': v['max'], 'agreement': v['agreement'] ?? ''};
                    next['ranges'] = r;
                    await api.postJson('/pay-criteria', next);
                  },
                );
                reload();
              }),
              for (final name in {...ranges.keys, ...suggestions.keys})
                entryCard(
                  context,
                  name,
                  ranges[name] == null
                      ? '${t('Noch kein bestätigtes Band', 'Ni potrjenega razpona')} · P10 ${object(suggestions[name])['p10'] ?? '—'} · Median ${object(suggestions[name])['median'] ?? '—'} · P90 ${object(suggestions[name])['p90'] ?? '—'} EUR'
                      : '${object(ranges[name])['min']} – ${object(ranges[name])['max']} EUR',
                  onTap: () async {
                    final result = await editData(
                      context,
                      title: name,
                      fields: const [
                        Input('min', 'Minimum EUR / Jahr', 'Najmanj EUR / leto', kind: 'number'),
                        Input('max', 'Maximum EUR / Jahr', 'Največ EUR / leto', kind: 'number'),
                        Input('agreement', 'Kollektivvertrag', 'Kolektivna pogodba'),
                        Input('remove', 'Dieses Band entfernen', 'Odstrani ta razpon', kind: 'bool'),
                      ],
                      initial: object(ranges[name]),
                      save: (v) async {
                        final next = copyData(document);
                        final r = object(next['ranges']);
                        if (v['remove'] == true) {
                          r.remove(name);
                        } else {
                          r[name] = {'min': v['min'], 'max': v['max'], 'agreement': v['agreement'] ?? ''};
                        }
                        next['ranges'] = r;
                        await api.postJson('/pay-criteria', next);
                      },
                    );
                    if (result != null) reload();
                  },
                ),
              button(
                t('Entgeltentwicklung bearbeiten', 'Uredi napredovanje plač'),
                () => edit(
                  t('Entgeltentwicklung', 'Napredovanje plač'),
                  const [
                    Input(
                      'progression',
                      'Objektive Kriterien der Entwicklung',
                      'Objektivna merila napredovanja',
                      kind: 'long',
                    ),
                  ],
                  document,
                  '/pay-criteria',
                ),
              ),
              formats(t('Kriterien für Beschäftigte', 'Merila za zaposlene'), '/pay-criteria/document', {
                'year': year,
                'kind': 'criteria',
              }),
              formats(t('Gehaltsangaben für Stellenanzeigen', 'Plačni podatki za oglase'), '/pay-criteria/document', {
                'year': year,
                'kind': 'vacancy',
              }),
            ];
          case 'obligations':
            final document = object(d['document']), entries = object(document['records']), state = object(d['state']);
            const controlNames = {
              'scope': 'Anwendungsbereich / Področje uporabe',
              'recruitment': 'Einstellung / Zaposlovanje',
              'criteriaAccess': 'Kriterienzugang / Dostop do meril',
              'payDisclosure': 'Entgelt-Geheimhaltung / Tajnost plač',
              'accessibility': 'Barrierefreiheit / Dostopnost',
              'distribution': 'Berichtszustellung / Dostava poročil',
              'privacy': 'Datenschutz / Zasebnost',
              'socialDialogue': 'Sozialer Dialog / Socialni dialog',
              'remedies': 'Rechtsdurchsetzung / Uveljavljanje pravic',
              'procurement': 'Öffentliche Aufträge / Javna naročila',
              'retaliation': 'Benachteiligungsschutz / Zaščita pred povračilnimi ukrepi',
              'nationalReview': 'Nationale Regeln / Nacionalna pravila',
            };
            content = [
              NoticeBanner(
                t(
                  'Nachweise sind Angaben des Arbeitgebers und keine unabhängige Rechtsprüfung.',
                  'Dokazila so navedbe delodajalca, ne neodvisna pravna presoja.',
                ),
              ),
              const SizedBox(height: 16),
              for (final entry in controlNames.entries)
                entryCard(
                  context,
                  entry.value,
                  '${object(entries[entry.key])['status'] ?? 'open'}${state['stale'] == true ? ' · veraltet / zastarelo' : ''}',
                  onTap: () async {
                    final result = await editData(
                      context,
                      title: entry.value,
                      fields: [
                        Input(
                          'status',
                          'Stand',
                          'Stanje',
                          options: {
                            'open': 'Offen / Odprto',
                            'recorded': 'Nachweis erfasst / Dokazilo vneseno',
                            if (entry.key == 'procurement') 'not_applicable': 'Nicht anwendbar / Se ne uporablja',
                          },
                        ),
                        const Input('owner', 'Verantwortlich', 'Odgovorna oseba'),
                        const Input('reviewedOn', 'Geprüft am (YYYY-MM-DD)', 'Preverjeno dne', kind: 'date'),
                        const Input('evidence', 'Nachweis / Referenz', 'Dokazilo / referenca', kind: 'long'),
                        const Input('action', 'Offene Maßnahme', 'Odprt ukrep', kind: 'long'),
                        const Input('due', 'Frist (YYYY-MM-DD)', 'Rok', kind: 'date'),
                      ],
                      initial: object(entries[entry.key]),
                      save: (v) async {
                        final next = copyData(document);
                        final r = object(next['records']);
                        r[entry.key] = v;
                        next['records'] = r;
                        next['snapshotId'] = d['snapshotId'];
                        await api.postJson('/employer-controls', {'year': year, 'document': next});
                      },
                    );
                    if (result != null) reload();
                  },
                ),
              for (final format in ['pdf', 'txt', 'html', 'json'])
                button(
                  '${t('Nachweise exportieren', 'Izvozi dokazila')} · ${format.toUpperCase()}',
                  () => downloadFile(
                    context,
                    ref,
                    '/employer-controls/$format?year=$year',
                    'equitensa-obligations-$year.$format',
                  ),
                ),
              SectionTitle(t('Alle 37 Artikel', 'Vseh 37 členov')),
              for (final article in records(d['articles']))
                entryCard(context, 'Art. ${article['article']} · ${article[t.sl ? 'sl' : 'de']}', '${article['role']}'),
            ];
          case 'national':
            final country = d['country'], doc = object(d['document']), rule = object(d['rule']);
            content = [
              NoticeBanner('${rule['title']}\n${rule['scope']}'),
              const SizedBox(height: 16),
              if (rule['id'] == null)
                NoticeBanner(
                  t(
                    'Nationale Vorlage ist auf dem Backend noch nicht freigegeben.',
                    'Nacionalna predloga v zaledju še ni potrjena.',
                  ),
                )
              else ...[
                button(
                  t('Nationale Angaben bearbeiten', 'Uredi nacionalne podatke'),
                  () => edit(
                    t('Nationaler Bericht', 'Nacionalno poročilo'),
                    country == 'DE'
                        ? [
                            const Input(
                              'cycle',
                              'Berichtszyklus',
                              'Cikel',
                              options: {'three': '3 Jahre / leta', 'five': '5 Jahre / let'},
                            ),
                            const Input('firstReport', 'Erster Bericht', 'Prvo poročilo', kind: 'bool'),
                            const Input(
                              'equalityMeasures',
                              'Gleichstellungsmaßnahmen',
                              'Ukrepi za enakost',
                              kind: 'long',
                            ),
                            const Input('equalityEffects', 'Wirkung der Maßnahmen', 'Učinki ukrepov', kind: 'long'),
                            const Input(
                              'equalPayMeasures',
                              'Maßnahmen zur Entgeltgleichheit',
                              'Ukrepi za enako plačilo',
                              kind: 'long',
                            ),
                            for (final group in ['counts', 'previousCounts'])
                              for (final sex in ['men', 'women'])
                                for (final time in ['fullTime', 'partTime'])
                                  Input(
                                    '$group.$sex.$time',
                                    '${group == 'counts' ? 'Aktuell' : 'Vorher'} · $sex · $time',
                                    '${group == 'counts' ? 'Trenutno' : 'Prej'} · $sex · $time',
                                    kind: 'number',
                                  ),
                            const Input(
                              'previousYear',
                              'Vorheriges Berichtsjahr',
                              'Prejšnje leto poročanja',
                              kind: 'number',
                            ),
                            const Input(
                              'confirmed',
                              'Angaben geprüft und bestätigt',
                              'Podatki preverjeni in potrjeni',
                              kind: 'bool',
                            ),
                          ]
                        : const [
                            Input(
                              'csv',
                              'AT-Zusatzdaten CSV (Semikolon): internal_id;pay_group;group_year;time_dependent_annual;time_independent_annual;fte_fraction;year_fraction',
                              'Dodatni podatki AT CSV',
                              kind: 'fileText',
                              required: true,
                            ),
                            Input('anonymityReviewed', 'Anonymität geprüft', 'Preverjena anonimnost', kind: 'bool'),
                            Input('confirmed', 'Datenumfang bestätigt', 'Potrjen obseg podatkov', kind: 'bool'),
                          ],
                    {'firstReport': false, ...doc},
                    '/national-report',
                  ),
                ),
                formats(
                  t('Nationalen Bericht herunterladen', 'Prenesi nacionalno poročilo'),
                  '/national-report/document',
                  {'year': year},
                ),
              ],
            ];
          case 'payroll':
            final codes = records(d['codes']);
            content = [
              entryCard(
                context,
                t('Dateien hinzufügen', 'Dodaj datoteke'),
                t('Personalstamm und monatliche Buchungen', 'Kadrovski podatki in mesečne transakcije'),
                onTap: () => context.push('/pay/import'),
              ),
              NoticeBanner(
                '${t('Arbeitsstand', 'Delovni posnetek')}: ${d['version']} · ${d['ready'] == true ? t('Bereit', 'Pripravljen') : t('Unvollständig', 'Nepopoln')}',
              ),
              const SizedBox(height: 18),
              for (final code in codes)
                entryCard(
                  context,
                  '${code['source']} · ${code['code']}',
                  '${code['classification']}',
                  onTap: () async {
                    final result = await editData(
                      context,
                      title: '${code['code']}',
                      fields: const [
                        Input(
                          'classification',
                          'Entgeltbestandteil',
                          'Sestavina plačila',
                          options: {
                            'unknown': 'Offen / Odprto',
                            'ordinary': 'Grundvergütung / Osnovno plačilo',
                            'variable': 'Variabel / Variabilno',
                            'excluded': 'Ausgeschlossen / Izključeno',
                          },
                        ),
                        Input(
                          'reason',
                          'Geprüfte Grundlage / Begründung',
                          'Preverjena podlaga / obrazložitev',
                          kind: 'long',
                          required: true,
                        ),
                      ],
                      initial: code,
                      save: (v) async {
                        await api.postJson('/payroll/codes', {
                          'year': year,
                          'version': d['version'],
                          'codes': [v],
                        });
                      },
                    );
                    if (result != null) reload();
                  },
                ),
              for (final error in records(d['errors']))
                NoticeBanner('${error['error']} · ${error['period'] ?? ''} · ${error['pay_code'] ?? ''}'),
              button(t('Jahresdaten berechnen', 'Izračunaj letne podatke'), () async {
                if (!await confirmAction(
                  context,
                  t('Jahresdaten berechnen', 'Izračunaj letne podatke'),
                  t(
                    'Jahresumfang, Monate, Entgeltbestandteile und Stunden geprüft? Dieser Stand ersetzt den Arbeitsdatenstand des Berichts.',
                    'Ste preverili letni obseg, mesece, sestavine plačila in ure? Ta posnetek nadomesti delovne podatke poročila.',
                  ),
                )) {
                  return;
                }
                await api.postJson('/payroll/finalize', {
                  'year': year,
                  'version': d['version'],
                  'contextConfirmed': true,
                });
                ref.invalidate(payAnalysisProvider);
                ref.invalidate(payReadinessProvider);
                reload();
              }),
              button(t('Monatlichen Entwurf leeren', 'Izprazni mesečni osnutek'), () async {
                if (!await confirmAction(
                  context,
                  t('Entwurf leeren', 'Izprazni osnutek'),
                  t(
                    'Monatliche Arbeitsdaten entfernen? Bestehende Jahresdatenstände bleiben erhalten.',
                    'Želite odstraniti mesečne delovne podatke? Letni posnetki ostanejo.',
                  ),
                )) {
                  return;
                }
                await api.postJson('/payroll/reset', {'year': year, 'version': d['version'], 'confirmReset': true});
                reload();
              }),
            ];
          case 'integrations':
            content = [
              entryCard(
                context,
                t('Dateiimport', 'Uvoz datotek'),
                t('Vorschau, Zuordnung und Bestätigung', 'Predogled, preslikava in potrditev'),
                onTap: () => context.push('/pay/import'),
              ),
              entryCard(
                context,
                t('Monatliche Abrechnung', 'Mesečni obračun'),
                '',
                onTap: () => context.push('/pay/payroll'),
              ),
              SectionTitle(t('API-Schlüssel', 'API ključi')),
              button(t('API-Schlüssel erstellen', 'Ustvari API ključ'), () async {
                Data? created;
                final result = await editData(
                  context,
                  title: t('Neuer API-Schlüssel', 'Nov API ključ'),
                  fields: const [Input('label', 'Bezeichnung', 'Oznaka', required: true)],
                  save: (v) async {
                    created = await api.postJson('/integrations/keys', v);
                  },
                );
                if (result == null || !context.mounted) return;
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (c) => AlertDialog(
                    title: Text(t('Schlüssel einmalig sichern', 'Ključ shranite zdaj')),
                    content: SelectableText('${created?['key']}'),
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('Gesichert', 'Shranjeno')))],
                  ),
                );
                reload();
              }),
              for (final key in records(items[1]['keys']))
                entryCard(
                  context,
                  '${key['label']}',
                  'eqt_${key['prefix']}… · ${key['revoked_at'] ?? 'aktiv'}',
                  onTap: key['revoked_at'] != null
                      ? null
                      : () => payAction(context, () async {
                          if (!await confirmAction(
                            context,
                            t('Schlüssel sperren', 'Blokiraj ključ'),
                            '${key['label']}',
                          )) {
                            return;
                          }
                          await api.postJson('/integrations/keys/${key['id']}/revoke', {});
                          reload();
                        }),
                ),
              SectionTitle(t('API-Lieferungen', 'API pošiljke')),
              for (final batch in records(items[2]['batches']))
                entryCard(
                  context,
                  '${batch['source']} · ${batch['record_count']}',
                  '${batch['reporting_year']} · ${batch['status']}',
                  onTap: batch['status'] == 'pending' ? () => context.push('/pay/import?batch=${batch['id']}') : null,
                  trailing: batch['status'] == 'pending'
                      ? IconButton(
                          tooltip: t('Verwerfen', 'Zavrzi'),
                          icon: const Icon(Icons.close),
                          onPressed: () => payAction(context, () async {
                            if (!await confirmAction(
                              context,
                              t('Lieferung verwerfen', 'Zavrzi pošiljko'),
                              '${batch['source']}',
                            )) {
                              return;
                            }
                            await api.postJson('/integrations/batches/${batch['id']}/discard', {});
                            reload();
                          }),
                        )
                      : null,
                ),
              NoticeBanner('HTTPS API: ${object(d['push'])['endpoint'] ?? '/api/ingest/v1/employees'}\nAuthorization: Bearer <API key>'),
              const SizedBox(height: 16),
              for (final line in object(d['requiredData'])[t.sl?'sl':'de'] as List? ?? []) entryCard(context, line.toString(), ''),
              for (final guide in records(d['guides'])) ExpansionTile(title: Text('${guide['name']}'), subtitle: Text('${guide['mode'] ?? ''}'), children: [Padding(padding: const EdgeInsets.all(16), child: Text(object(guide['note'])[t.sl?'sl':'de']?.toString() ?? '')), for (final line in object(guide['steps'])[t.sl?'sl':'de'] as List? ?? []) ListTile(title: Text(line.toString()))]),
              SectionTitle(t('Integrationen', 'Povezave')),
              for (final provider in records(d['providers']))
                entryCard(
                  context,
                  '${provider['name'] ?? provider['id']}',
                  '${provider['status'] ?? ''} · ${provider['description'] ?? ''}',
                ),
              for (final batch in records(items[3]['batches']))
                entryCard(
                  context,
                  t('Importverlauf', 'Zgodovina uvoza'),
                  '${batch['created_at']} · ${batch['format']} · v${batch['mapping_version']}',
                ),
            ];
          case 'retention':
            final policy = object(d['policy']);
            content = [
              NoticeBanner(
                '${t('Aufbewahrung bis', 'Hramba do')}: ${d['reviewDue'] ?? '—'} · ${d['held'] == true ? t('Sperre aktiv', 'Aktivno zadržanje') : ''}',
              ),
              const SizedBox(height: 18),
              button(
                t('Aufbewahrungsrichtlinie bearbeiten', 'Uredi pravilnik hrambe'),
                () => edit(
                  t('Aufbewahrungsrichtlinie', 'Pravilnik hrambe'),
                  const [
                    Input('purpose', 'Zweck', 'Namen', kind: 'long', required: true),
                    Input('legalBasis', 'Rechtsgrundlage', 'Pravna podlaga', kind: 'long', required: true),
                    Input(
                      'retentionMonths',
                      'Monate ab Jahresende',
                      'Meseci od konca leta',
                      kind: 'number',
                      required: true,
                    ),
                    Input('owner', 'Verantwortlich', 'Odgovorna oseba', required: true),
                    Input('reviewedOn', 'Geprüft am (YYYY-MM-DD)', 'Preverjeno dne', kind: 'date', required: true),
                    Input(
                      'backupProcedure',
                      'Backups und Empfänger',
                      'Kopije in prejemniki',
                      kind: 'long',
                      required: true,
                    ),
                    Input(
                      'confirmed',
                      'Fachlich geprüft und bestätigt',
                      'Strokovno preverjeno in potrjeno',
                      kind: 'bool',
                    ),
                  ],
                  policy,
                  '/data-retention',
                  envelope: 'policy',
                ),
              ),
              button(t('Aufbewahrungssperre hinzufügen', 'Dodaj zadržanje izbrisa'), () async {
                await editData(
                  context,
                  title: t('Aufbewahrungssperre', 'Zadržanje izbrisa'),
                  initial: {'year': year},
                  fields: const [
                    Input('year', 'Jahr', 'Leto', kind: 'number'),
                    Input('reason', 'Grund', 'Razlog', kind: 'long', required: true),
                  ],
                  save: (v) async {
                    final next = copyData(policy);
                    next['holds'] = [...records(next['holds']), v];
                    await api.postJson('/data-retention', {'policy': next});
                  },
                );
                reload();
              }),
              for (final hold in records(policy['holds']))
                entryCard(
                  context,
                  '${hold['year']}',
                  '${hold['reason']}',
                  onTap: () => payAction(context, () async {
                    if (!await confirmAction(
                      context,
                      t('Sperre entfernen', 'Odstrani zadržanje'),
                      '${hold['year']} · ${hold['reason']}',
                    )) {
                      return;
                    }
                    final next = copyData(policy);
                    next['holds'] = records(next['holds']).where((h) => h['year'] != hold['year']).toList();
                    await api.postJson('/data-retention', {'policy': next});
                    reload();
                  }),
                ),
              for (final count in object(d['counts']).entries) entryCard(context, count.key, '${count.value}'),
              button(t('Löschung dieses Jahres vorbereiten', 'Pripravi izbris tega leta'), () async {
                final country = ref.read(countryProvider).code;
                final confirmation = '$country $year DELETE';
                await editData(
                  context,
                  title: t('Jahr unwiderruflich löschen', 'Nepovratno izbriši leto'),
                  initial: {'year': year, 'fingerprint': d['fingerprint']},
                  fields: [
                    Input(
                      'confirmation',
                      'Zum Löschen exakt eingeben: $confirmation',
                      'Za izbris vnesite: $confirmation',
                      required: true,
                    ),
                    const Input('password', 'Aktuelles Passwort', 'Trenutno geslo', kind: 'password'),
                    const Input(
                      'legalReviewConfirmed',
                      'Rechtliche Prüfung der Löschung bestätigt',
                      'Potrjen pravni pregled izbrisa',
                      kind: 'bool',
                    ),
                    const Input(
                      'exceptionReason',
                      'Begründung bei vorzeitiger Löschung',
                      'Razlog predčasnega izbrisa',
                      kind: 'long',
                    ),
                    const Input(
                      'exceptionReviewed',
                      'Ausnahme fachlich geprüft',
                      'Izjema strokovno preverjena',
                      kind: 'bool',
                    ),
                  ],
                  action: t('Unwiderruflich löschen', 'Nepovratno izbriši'),
                  save: (v) async {
                    await api.postJson('/data-retention/delete-year', v);
                    ref.invalidate(payAnalysisProvider);
                    ref.invalidate(payReadinessProvider);
                  },
                );
                reload();
              }),
              SectionTitle(t('Löschbelege', 'Potrdila o izbrisu')),
              for (final receipt in records(items[1]['receipts']))
                entryCard(
                  context,
                  '${receipt['year']} · ${receipt['id']}',
                  '${receipt['backupStatus'] ?? ''}',
                  onTap: () => edit(
                    t('Backup-Löschung dokumentieren', 'Zabeleži izbris kopij'),
                    const [
                      Input('evidence', 'Nachweis / Referenz', 'Dokazilo / referenca', kind: 'long', required: true),
                      Input('confirmed', 'Durch Operator bestätigt', 'Potrjeno s strani izvajalca', kind: 'bool'),
                    ],
                    {'receiptId': receipt['id']},
                    '/data-retention/backup-complete',
                  ),
                ),
            ];
          case 'billing':
            final order = object(d['order']);
            content = [
              NoticeBanner('${t('Abrechnung', 'Obračun')}: ${d['mode']}'),
              const SizedBox(height: 16),
              entryCard(
                context,
                '${order['plan'] ?? t('Kein Paket', 'Brez paketa')}',
                '${order['status'] ?? ''} · ${order['interval'] ?? ''}',
              ),
              for (final plan in records(d['plans']))
                entryCard(
                  context,
                  '${plan['name'] ?? plan['id']}',
                  '${plan['monthly']} EUR / Monat · ${plan['annual']} EUR / Jahr',
                  onTap: () async {
                    Data? checkout;
                    final selected = await editData(
                      context,
                      title: '${plan['name'] ?? plan['id']}',
                      fields: const [
                        Input(
                          'interval',
                          'Zahlungsweise · Mindestlaufzeit 12 Monate',
                          'Plačevanje · minimalno obdobje 12 mesecev',
                          options: {'monthly': 'Monatlich / Mesečno', 'annual': 'Jährlich / Letno'},
                        ),
                        Input(
                          'accepted',
                          'Vertrag, 12 Monate Mindestlaufzeit, automatische Verlängerung, Nettopreis zzgl. USt. und Zahlungspflicht akzeptieren',
                          'Sprejemam pogodbo, 12 mesecev, samodejno podaljšanje, neto ceno z dodatnim DDV in obveznost plačila',
                          kind: 'bool',
                        ),
                      ],
                      initial: {'interval': 'annual'},
                      action: t('Zur Bestellung', 'Na naročilo'),
                      save: (v) async {
                        if (v['accepted'] != true) throw StateError('CONTRACT_ACCEPTANCE_REQUIRED');
                        if (!await confirmAction(
                          context,
                          t('Bestellung bestätigen', 'Potrdi naročilo'),
                          '${plan['name'] ?? plan['id']} · ${v['interval']} · ${v['interval'] == 'annual' ? plan['annual'] : plan['monthly']} EUR · ${t('12 Monate Mindestlaufzeit; zzgl. USt.', 'Minimalno obdobje 12 mesecev; DDV dodatno')}',
                        )) {
                          return;
                        }
                        checkout = await api.postJson('/billing/checkout', {
                          'plan': plan['id'],
                          'contractVersion': d['contractVersion'],
                          ...v,
                        });
                      },
                    );
                    if (selected == null || checkout == null) return;
                    if (checkout!['url'] != null) {
                      await launchUrl(Uri.parse(checkout!['url']), mode: LaunchMode.externalApplication);
                    } else if (checkout!['mode'] == 'sandbox' &&
                        context.mounted &&
                        await confirmAction(
                          context,
                          'Sandbox',
                          t('Testpaket ohne Zahlung aktivieren?', 'Aktivirate testni paket brez plačila?'),
                        )) {
                      await api.postJson('/billing/sandbox-confirm', {'orderId': object(checkout!['order'])['id']});
                    }
                    reload();
                  },
                ),
              if (order['mode'] == 'stripe')
                button(t('Zahlungsmittel und Rechnungen', 'Plačilna sredstva in računi'), () async {
                  final result = await api.postJson('/billing/portal', {});
                  await launchUrl(Uri.parse(result['url']), mode: LaunchMode.externalApplication);
                }),
              if (['active', 'sandbox_active', 'past_due'].contains(order['status']))
                button(t('Kündigung zum Vertragsende', 'Odpoved ob izteku pogodbe'), () async {
                  final preview = await api.getJson('/billing/cancellation');
                  if (!context.mounted ||
                      !await confirmAction(
                        context,
                        t('Kündigung bestätigen', 'Potrdi odpoved'),
                        '${preview['cancelAt']}',
                      )) {
                    return;
                  }
                  await api.postJson('/billing/cancellation', {'confirm': true, 'orderId': preview['orderId']});
                  reload();
                }),
            ];
          default:
            content = [
              button(t('Empfänger und Meldeplan prüfen', 'Preveri prejemnika in načrt poročanja'), () async {
                await editData(context, title: t('Meldeplan', 'Načrt poročanja'), initial: {'audience':'internal'}, fields: const [Input('audience','Empfänger','Prejemnik',options:{'internal':'Management & Vertretung / Vodstvo in predstavniki','authority':'Meldestelle / Organ','workers':'Beschäftigte / Zaposleni','public':'Öffentlich / Javno'})], action: t('Prüfen','Preveri'), save: (value) async {
                  final plan = await api.getJson('/reporting-plan?year=$year&audience=${value['audience']}');
                  if (!context.mounted) return;
                  await showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(t('Meldeplan','Načrt poročanja')), content: SingleChildScrollView(child: Text('${plan['country']} · ${plan['referenceYear']}\n${t('Bestätigte Beschäftigte','Potrjeni zaposleni')}: ${plan['headcount'] ?? '—'}\n${t('EU-Mindestfrist','Minimalni rok EU')}: ${object(plan['euMinimum'])['dueForReferenceYear'] ?? '—'}\n${object(plan['recipient'])['description']}\n${object(plan['national'])['status']}\n${t('Manueller Download; keine automatische Einreichung.','Ročni prenos; brez samodejne oddaje.')}\n${plan['source']}')), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
                });
              }),
              for (final format in ['pdf','txt','html','json']) button('${t('Umsetzungsnachweis','Dokazilo izvedbe')} $format', () => downloadFile(context,ref,'/evidence/$format?year=$year','equitensa-evidence-$year.$format')),
              button(t('Bericht herunterladen', 'Prenesi poročilo'), () async {
                await editData(
                  context,
                  title: t('Berichtsexport', 'Izvoz poročila'),
                  fields: const [
                    Input(
                      'audience',
                      'Empfänger',
                      'Prejemnik',
                      options: {
                        'internal': 'Management & Vertretung / Vodstvo in predstavniki',
                        'authority': 'Meldestelle / Organ',
                        'workers': 'Beschäftigte / Zaposleni',
                        'public': 'Öffentlich / Javno',
                      },
                    ),
                    Input(
                      'type',
                      'Berichtstyp',
                      'Vrsta poročila',
                      options: {
                        'report': 'Entgeltbericht / Poročilo o plačah',
                        'assessment': 'Gemeinsame Entgeltbewertung / Skupna ocena',
                      },
                    ),
                    Input(
                      'format',
                      'Format',
                      'Oblika',
                      options: {
                        'pdf': 'PDF',
                        'csv': 'CSV',
                        'xml': 'XML',
                        'txt': 'TXT',
                        'xlsx': 'XLSX',
                        'json': 'JSON',
                        'html': 'HTML',
                      },
                    ),
                    Input(
                      'prepared',
                      'Freigegebenen Stand exportieren (Paket & Vollständigkeit erforderlich)',
                      'Izvozi potrjen posnetek (potreben paket in popolnost)',
                      kind: 'bool',
                    ),
                  ],
                  initial: {'audience': 'internal', 'type': 'report', 'format': 'pdf', 'prepared': false},
                  action: t('Herunterladen', 'Prenesi'),
                  save: (v) async {
                    final query = Uri(
                      queryParameters: {
                        'year': '$year',
                        'audience': v['audience'],
                        'type': v['type'],
                        'prepared': '${v['prepared'] == true}',
                      },
                    ).query;
                    await downloadFile(
                      context,
                      ref,
                      '/reports/${v['format']}?$query',
                      'equitensa-report-$year.${v['format']}',
                    );
                  },
                );
              }),
              NoticeBanner(
                t(
                  'Entwürfe und freigegebene Berichte werden vom Backend unterschieden. Die App reicht nichts automatisch bei Behörden ein.',
                  'Osnutke in potrjena poročila razlikuje strežnik. Aplikacija ničesar samodejno ne odda organom.',
                ),
              ),
              const SizedBox(height: 16),
              for (final check in records(object(d['readiness'])['checks']))
                entryCard(
                  context,
                  '${check['id']}',
                  check['done'] == true ? t('Erledigt', 'Opravljeno') : t('Offen', 'Odprto'),
                ),
              entryCard(
                context,
                t('Nationaler Bericht', 'Nacionalno poročilo'),
                '',
                onTap: () => context.push('/pay/national'),
              ),
            ];
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (module != 'billing') ...[const YearSelector(), const SizedBox(height: 24)],
            ...content,
          ],
        );
      },
    );
  }
}
