import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/ui.dart';
import '../workspace/workspace_widgets.dart';

const factors = ['skills', 'effort', 'responsibility', 'conditions'];
const factorNames = ['Fähigkeiten', 'Belastung', 'Verantwortung', 'Arbeitsbedingungen'];
const factorSl = ['Spretnosti', 'Napor', 'Odgovornost', 'Delovne razmere'];
const profileInputs = [
  Input('legalName', 'Rechtlicher Firmenname', 'Pravni naziv podjetja', required: true),
  Input('headcount', 'Beschäftigte insgesamt', 'Skupno število zaposlenih', kind: 'number', required: true),
  Input(
    'payrollComplete',
    'Alle Entgeltbestandteile und bezahlten Stunden geprüft',
    'Preverjene vse sestavine plačila in plačane ure',
    kind: 'bool',
  ),
];

class PayWorkflowScreen extends ConsumerWidget {
  const PayWorkflowScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return RemotePage(
      title: t('Bericht vorbereiten', 'Priprava poročila'),
      load: (ref) async {
        final api = ref.read(apiClientProvider), year = ref.read(payYearProvider);
        final responses = await Future.wait([
          api.getJson('/workflow?year=$year'),
          api.getJson('/employer-context?year=$year'),
        ]);
        return {...responses[0], 'context': responses[1], 'year': year};
      },
      builder: (context, ref, data, reload) {
        final year = data['year'];
        final employer = object(data['context']);
        final workflow = copyData(object(data['workflow']));
        final current = workflow['snapshotId'] == employer['snapshotId'];
        // Retain the snapshot loaded with this editor. A concurrent web import must fail on the server.
        if (!current) {
          workflow.clear();
        }
        workflow['snapshotId'] = employer['snapshotId'];
        workflow['profile'] ??= {
          'legalName': ref.read(sessionProvider).value?.company.name,
          'headcount': null,
          'payrollComplete': false,
        };
        Future<void> save(Data next) async {
          await ref.read(apiClientProvider).postJson('/workflow', {'year': year, 'workflow': next});
          ref.invalidate(payReadinessProvider);
          ref.invalidate(payAnalysisProvider);
        }

        Future<void> editSection(String key, String title, List<Input> fields, {Data? initial}) async {
          final edited = await editData(
            context,
            title: title,
            fields: fields,
            initial: initial ?? object(workflow[key]),
            save: (value) async {
              final next = copyData(workflow);
              next[key] = value;
              await save(next);
            },
          );
          if (edited != null) reload();
        }

        Future<void> editCategory(String key, String category, List<Input> fields, {Data? initial}) async {
          final edited = await editData(
            context,
            title: category,
            fields: fields,
            initial: initial ?? object(object(workflow[key])[category]),
            save: (value) async {
              final next = copyData(workflow);
              final section = object(next[key]);
              section[category] = value;
              next[key] = section;
              await save(next);
            },
          );
          if (edited != null) reload();
        }

        final readiness = object(data['readiness']);
        final categories = records(employer['categories']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const YearSelector(),
            const SizedBox(height: 20),
            EqCard(
              child: Row(
                children: [
                  CompletionRing(
                    percent: (readiness['percent'] as num? ?? 0).toInt(),
                    label: t('Berichtsfortschritt', 'Napredek poro?ila'),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      t('Ihr Bericht entsteht Schritt für Schritt.', 'Vaše poročilo nastaja korak za korakom.'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            entryCard(
              context,
              t('1 · Daten importieren', '1 · Uvoz podatkov'),
              t('Jahresdaten oder monatliche Abrechnung', 'Letni podatki ali mesečni obračun'),
              onTap: () => context.push('/pay/import'),
            ),
            if (employer['snapshotId'] == null)
              NoticeBanner(t('Zuerst Gehaltsdaten importieren.', 'Najprej uvozite podatke o plačah.'))
            else ...[
              if (!current)
                NoticeBanner(
                  t(
                    'Neuer Datenstand: Angaben und Freigaben erneut prüfen.',
                    'Nov podatkovni posnetek: ponovno preverite podatke in potrditve.',
                  ),
                ),
              entryCard(
                context,
                t('2 · Unternehmensprofil', '2 · Profil podjetja'),
                object(workflow['profile'])['legalName']?.toString() ?? '',
                onTap: () => editSection('profile', t('Unternehmensprofil', 'Profil podjetja'), profileInputs),
              ),
              entryCard(
                context,
                t('3 · Vereinbarung der Kriterien', '3 · Dogovor o merilih'),
                object(workflow['criteriaAgreement'])['status']?.toString() ?? '',
                onTap: () => editSection('criteriaAgreement', t('Vereinbarung', 'Dogovor'), [
                  Input(
                    'status',
                    'Stand',
                    'Stanje',
                    options: {
                      'pending': t('Offen', 'Odprto'),
                      'agreed': t('Mit Vertretung vereinbart', 'Dogovorjeno s predstavniki'),
                      'no_representatives': t('Keine Arbeitnehmervertretung', 'Brez predstavnikov delavcev'),
                    },
                  ),
                  const Input('note', 'Begründung / Referenz', 'Obrazložitev / referenca', kind: 'long'),
                ]),
              ),
              SectionTitle(t('Gleiche und gleichwertige Arbeit', 'Enako in enakovredno delo')),
              for (final category in categories)
                entryCard(
                  context,
                  category['category'].toString(),
                  t('Vier Kriterien dokumentieren', 'Dokumentirajte štiri merila'),
                  trailing: const Icon(LucideIcons.pencil, size: 17),
                  onTap: () => editCategory('classification', category['category'].toString(), [
                    for (var i = 0; i < 4; i++)
                      Input(factors[i], factorNames[i], factorSl[i], kind: 'long', required: true),
                  ]),
                ),
              entryCard(
                context,
                t('Arbeitsbewertung · Methodik', 'Vrednotenje dela · metodologija'),
                object(workflow['jobEvaluation'])['mode']?.toString() ?? '',
                onTap: () => editSection('jobEvaluation', t('Arbeitsbewertung', 'Vrednotenje dela'), [
                  Input(
                    'mode',
                    'Verfahren',
                    'Metoda',
                    options: {
                      'documented': t('Dokumentiert', 'Dokumentirano'),
                      'scored': t('Punktebewertung', 'Točkovanje'),
                    },
                  ),
                  const Input('methodology', 'Methodik', 'Metodologija', kind: 'long'),
                  const Input('reference', 'Beleg / Referenz', 'Dokazilo / referenca'),
                  const Input('assessedBy', 'Bewertet durch', 'Ocenil'),
                  const Input('assessedOn', 'Bewertet am (YYYY-MM-DD)', 'Datum ocene (YYYY-MM-DD)', kind: 'date'),
                  const Input(
                    'genderNeutralConfirmed',
                    'Geschlechtsneutrale Anwendung geprüft',
                    'Preverjena spolno nevtralna uporaba',
                    kind: 'bool',
                  ),
                  for (var i = 0; i < 4; i++)
                    Input(
                      'weights.${factors[i]}',
                      '${factorNames[i]} · Gewicht % (zusammen 100)',
                      '${factorSl[i]} · utež % (skupaj 100)',
                      kind: 'number',
                    ),
                ]),
              ),
              for (final category in categories)
                entryCard(
                  context,
                  '${t('Bewertung', 'Vrednotenje')}: ${category['category']}',
                  (category['titles'] as List? ?? []).join(' · '),
                  onTap: () async {
                    final evaluation = object(workflow['jobEvaluation']);
                    final entries = object(evaluation['categories']);
                    final name = category['category'].toString();
                    final entry = object(entries[name]);
                    final titles = (category['titles'] as List? ?? []).cast<String>();
                    final oldRoles = records(entry['roles']);
                    entry['roles'] = [
                      for (final title in titles)
                        oldRoles.where((r) => r['title'] == title).firstOrNull ?? {'title': title, 'scores': {}},
                    ];
                    final result = await editData(
                      context,
                      title: name,
                      initial: entry,
                      fields: [
                        const Input(
                          'rationale',
                          'Zuordnung und Begründung',
                          'Razvrstitev in obrazložitev',
                          kind: 'long',
                        ),
                        const Input('evidence', 'Belege', 'Dokazila', kind: 'long'),
                        if (evaluation['mode'] == 'scored')
                          for (var j = 0; j < titles.length; j++) ...[
                            for (var i = 0; i < 4; i++)
                              Input(
                                'roles.$j.scores.${factors[i]}',
                                '${titles[j]} · ${factorNames[i]} (1–5)',
                                '${titles[j]} · ${factorSl[i]} (1–5)',
                                kind: 'number',
                              ),
                            Input(
                              'roles.$j.evidence',
                              '${titles[j]} · Belege',
                              '${titles[j]} · Dokazila',
                              kind: 'long',
                            ),
                          ],
                      ],
                      save: (value) async {
                        final next = copyData(workflow);
                        entries[name] = value;
                        evaluation['categories'] = entries;
                        next['jobEvaluation'] = evaluation;
                        await save(next);
                      },
                    );
                    if (result != null) reload();
                  },
                ),
              entryCard(
                context,
                t('4 · Analyse', '4 · Analiza'),
                t('Kennzahlen und Gruppen vergleichen', 'Primerjajte kazalnike in skupine'),
                onTap: () => context.push('/pay'),
              ),
              SectionTitle(t('Unterschiede prüfen und Maßnahmen erfassen', 'Pregled razlik in ukrepov')),
              for (final category in categories)
                entryCard(
                  context,
                  category['category'].toString(),
                  object(object(workflow['reviews'])[category['category']])['explanation']?.toString() ??
                      t('Prüfung offen', 'Pregled je odprt'),
                  onTap: () => editCategory('reviews', category['category'].toString(), const [
                    Input('explanation', 'Objektive Begründung', 'Objektivna obrazložitev', kind: 'long'),
                    Input(
                      'justified',
                      'Unterschied objektiv gerechtfertigt',
                      'Razlika je objektivno utemeljena',
                      kind: 'bool',
                    ),
                    Input('action', 'Maßnahme', 'Ukrep', kind: 'long'),
                    Input('owner', 'Verantwortlich', 'Odgovorna oseba'),
                    Input('due', 'Frist (YYYY-MM-DD)', 'Rok (YYYY-MM-DD)', kind: 'date'),
                    Input('proof.completedOn', 'Abhilfe abgeschlossen am', 'Odprava zaključena dne', kind: 'date'),
                    Input('proof.evidence', 'Abhilfe · Beleg', 'Odprava · dokazilo', kind: 'long'),
                    Input('proof.verifiedBy', 'Geprüft durch', 'Preveril'),
                    Input('proof.verifiedOn', 'Geprüft am', 'Preverjeno dne', kind: 'date'),
                    Input('proof.verification', 'Ergebnis der Prüfung', 'Rezultat preverjanja', kind: 'long'),
                    Input('proof.baselineSnapshotId', 'Vorheriger Datenstand', 'Prejšnji podatkovni posnetek'),
                    Input('proof.targetSnapshotId', 'Geprüfter Datenstand', 'Preverjeni podatkovni posnetek'),
                    Input(
                      'remedied',
                      'Abhilfe nachweislich abgeschlossen',
                      'Odprava dokazano zaključena',
                      kind: 'bool',
                    ),
                  ]),
                ),
              SectionTitle(t('Gemeinsame Entgeltbewertung', 'Skupna ocena plač')),
              entryCard(
                context,
                t('Frühere Maßnahmen und gemeinsame Prüfung', 'Prejšnji ukrepi in skupni pregled'),
                '',
                onTap: () => editSection('assessment', t('Gemeinsame Bewertung', 'Skupna ocena'), const [
                  Input('previousMeasures', 'Wirkung früherer Maßnahmen', 'Učinek prejšnjih ukrepov', kind: 'long'),
                  Input(
                    'jointReviewConfirmed',
                    'Gemeinsam mit der Vertretung geprüft',
                    'Skupaj pregledano s predstavniki',
                    kind: 'bool',
                  ),
                ]),
              ),
              for (final category in categories)
                entryCard(
                  context,
                  '${t('Rückkehr aus Urlaub', 'Vrnitev z dopusta')}: ${category['category']}',
                  '',
                  onTap: () async {
                    final assessment = object(workflow['assessment']);
                    final outcomes = object(assessment['leaveOutcomes']);
                    final name = category['category'].toString();
                    final result = await editData(
                      context,
                      title: name,
                      initial: object(outcomes[name]),
                      fields: const [
                        Input(
                          'applicable',
                          'Rückkehrende mit relevanten Verbesserungen vorhanden',
                          'Prisotne vrnitve z ustreznimi izboljšavami',
                          kind: 'bool',
                        ),
                        Input('note', 'Begründung / Hinweis', 'Obrazložitev / opomba', kind: 'long'),
                        Input('men.eligible', 'Männer · berechtigt', 'Moški · upravičeni', kind: 'number'),
                        Input('men.benefited', 'Männer · profitiert', 'Moški · prejemniki', kind: 'number'),
                        Input('women.eligible', 'Frauen · berechtigt', 'Ženske · upravičene', kind: 'number'),
                        Input('women.benefited', 'Frauen · profitiert', 'Ženske · prejemnice', kind: 'number'),
                      ],
                      save: (value) async {
                        final next = copyData(workflow);
                        outcomes[name] = value;
                        assessment['leaveOutcomes'] = outcomes;
                        next['assessment'] = assessment;
                        await save(next);
                      },
                    );
                    if (result != null) reload();
                  },
                ),
              entryCard(
                context,
                t('5 · Freigabe', '5 · Potrditev'),
                t('Verantwortliche und Konsultation bestätigen', 'Potrdite odgovorne osebe in posvetovanje'),
                onTap: () => editSection('approval', t('Freigabe', 'Potrditev'), const [
                  Input('manager', 'Geschäftsleitung', 'Vodstvo'),
                  Input(
                    'representatives',
                    'Arbeitnehmervertretung / Begründung',
                    'Predstavniki delavcev / obrazložitev',
                    kind: 'long',
                  ),
                  Input(
                    'confirmed',
                    'Richtigkeit durch Geschäftsleitung bestätigt',
                    'Vodstvo je potrdilo pravilnost',
                    kind: 'bool',
                  ),
                  Input(
                    'consulted',
                    'Vertretung konsultiert und Zugang zur Methodik gewährt',
                    'Predstavniki so bili vključeni in imajo dostop do metodologije',
                    kind: 'bool',
                  ),
                ]),
              ),
              entryCard(
                context,
                t('Datum der Berichterstattung', 'Datum poročanja'),
                workflow['reportingDate']?.toString() ?? '',
                onTap: () async {
                  final result = await editData(
                    context,
                    title: t('Berichterstattung', 'Poročanje'),
                    initial: {'reportingDate': workflow['reportingDate']},
                    fields: const [Input('reportingDate', 'Datum (YYYY-MM-DD)', 'Datum (YYYY-MM-DD)', kind: 'date')],
                    save: (v) async {
                      final next = copyData(workflow);
                      next['reportingDate'] = v['reportingDate'];
                      await save(next);
                    },
                  );
                  if (result != null) reload();
                },
              ),
              for (final missing in records(readiness['missing']))
                NoticeBanner(
                  '${missing['step']} · ${missing['field']}${missing['category'] == null ? '' : ' · ${missing['category']}'}',
                ),
              entryCard(
                context,
                t('6 · Berichte exportieren', '6 · Izvoz poročil'),
                t('Empfänger, Format und Freigabestand wählen', 'Izberite prejemnika, obliko in stanje potrditve'),
                onTap: () => context.push('/pay/exports'),
              ),
            ],
          ],
        );
      },
    );
  }
}
