import 'package:material_ui/material_ui.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../workspace/workspace_widgets.dart';

const reportSteps = ['data', 'profile', 'categories', 'reviews', 'approval'];

String reportStepTitle(String id, Tr t) => switch (id) {
  'data' => t('Gehaltsdaten', 'Podatki o plačah'),
  'profile' => t('Unternehmensprofil', 'Profil podjetja'),
  'categories' => t('Kriterien & Arbeitsbewertung', 'Merila in vrednotenje dela'),
  'reviews' => t('Unterschiede & Maßnahmen', 'Razlike in ukrepi'),
  'approval' => t('Freigabe & Konsultation', 'Potrditev in posvetovanje'),
  _ => t('Gemeinsame Entgeltbewertung', 'Skupna ocena plač'),
};

/// These are presentation labels for server requirements, never local legal checks.
String reportRequirement(Data item, Tr t) {
  final labels = <String, String>{
    'payroll': t('Jahresdaten importieren', 'Uvozite letne podatke'),
    'currentSnapshot': t('Aktuellen Datenstand prüfen und speichern', 'Preverite in shranite trenutne podatke'),
    'snapshot': t('Aktuellen Datenstand prüfen und speichern', 'Preverite in shranite trenutne podatke'),
    'legalName': t('Rechtlichen Unternehmensnamen ergänzen', 'Dopolnite pravno ime podjetja'),
    'headcount': t(
      'Beschäftigtenzahl prüfen: mindestens so viele wie im Datenbestand',
      'Preverite število zaposlenih: najmanj toliko kot v podatkih',
    ),
    'payrollComplete': t(
      'Alle Entgeltbestandteile und bezahlten Stunden bestätigen',
      'Potrdite vse sestavine plačila in plačane ure',
    ),
    'criteriaAgreement': t(
      'Kriterienvereinbarung oder fehlende Vertretung dokumentieren',
      'Dokumentirajte dogovor o merilih ali odsotnost predstavnikov',
    ),
    'evaluation': t(
      'Bewertungsmethode und Nachweise vervollständigen',
      'Dopolnite metodologijo vrednotenja in dokazila',
    ),
    'classification': t('Alle vier Vergleichskriterien beschreiben', 'Opišite vsa štiri primerjalna merila'),
    'explanation': t(
      'Entgeltunterschied mit Belegen erklären, auch unter 5 %',
      'Pojasnite razliko v plači z dokazili, tudi pod 5 %',
    ),
    'reasons': t('Gründe für Entgeltunterschiede dokumentieren', 'Dokumentirajte razloge za razlike v plačah'),
    'measures': t('Maßnahme, verantwortliche Person und Termin ergänzen', 'Dodajte ukrep, odgovorno osebo in rok'),
    'manager': t('Verantwortliche Person der Unternehmensleitung angeben', 'Navedite odgovorno osebo vodstva'),
    'representatives': t(
      'Vertretung und Konsultation oder begründeten Ersatzprozess beschreiben',
      'Opišite predstavnike in posvetovanje ali utemeljen nadomestni postopek',
    ),
    'confirmation': t('Richtigkeit durch die Unternehmensleitung bestätigen', 'Vodstvo mora potrditi pravilnost'),
    'consultation': t(
      'Konsultation und Zugang zur Methodik bestätigen',
      'Potrdite posvetovanje in dostop do metodologije',
    ),
    'previousMeasures': t('Wirkung früherer Maßnahmen dokumentieren', 'Dokumentirajte učinek prejšnjih ukrepov'),
    'jointReview': t('Gemeinsame Prüfung mit der Vertretung bestätigen', 'Potrdite skupni pregled s predstavniki'),
    'leaveOutcomes': t(
      'Rückkehr aus Urlaub prüfen und Ergebnisse erfassen',
      'Preverite vrnitve z dopusta in zabeležite rezultate',
    ),
  };
  final details = <String, String>{
    'methodology': t('Methode', 'Metoda'),
    'reference': t('Belegreferenz', 'Referenca dokazila'),
    'assessedBy': t('Bewertende Person', 'Ocenjevalec'),
    'assessedOn': t('Bewertungsdatum', 'Datum vrednotenja'),
    'genderNeutralConfirmed': t('Geschlechtsneutrale Anwendung', 'Spolno nevtralna uporaba'),
    'weights': t('Gewichte: zusammen 100 %', 'Uteži: skupaj 100 %'),
  };
  final field = item['field']?.toString() ?? '';
  final detail = item['category']?.toString();
  return '${labels[field] ?? t('Angabe prüfen', 'Preverite podatek')}${detail == null ? '' : ' · ${field == 'evaluation' ? details[detail] ?? detail : detail}'}';
}

class ReportProgress extends StatelessWidget {
  const ReportProgress({super.key, required this.readiness, required this.t, required this.onStep});
  final Data readiness;
  final Tr t;
  final ValueChanged<String> onStep;

  @override
  Widget build(BuildContext context) {
    final checks = records(readiness['checks']);
    final done = checks.where((c) => c['done'] == true).length;
    final ready = readiness['ready'] == true;
    final percent = ((readiness['percent'] as num?) ?? 0).clamp(0, 100).toInt();
    final next = reportSteps.where((id) => !checks.any((c) => c['id'] == id && c['done'] == true)).firstOrNull;
    return EqCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.eq.violetSoft, borderRadius: BorderRadius.circular(16)),
                child: Icon(ready ? Icons.task_alt : Icons.fact_check_outlined, color: context.eq.accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('IHR BERICHTSSTATUS', 'STANJE VAŠEGA POROČILA'),
                      style: TextStyle(
                        color: context.eq.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ready
                          ? t('Für den Bericht vorbereitet', 'Pripravljeno za poročilo')
                          : t('Schritt für Schritt zur Freigabe', 'Korak za korakom do potrditve'),
                      style: TextStyle(color: context.eq.ink, fontSize: 20, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  t(
                    '$done von ${checks.length} Prüfungen abgeschlossen',
                    '$done od ${checks.length} preverjanj zaključenih',
                  ),
                  style: TextStyle(color: context.eq.muted, fontSize: 12),
                ),
              ),
              Text(
                '$percent %',
                style: TextStyle(color: context.eq.accent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 7,
              backgroundColor: context.eq.lineSoft,
              color: context.eq.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t(
              'Status des gespeicherten Datenstands · gleiche Prüfungen wie im Web.',
              'Stanje shranjenih podatkov · ista preverjanja kot v spletni aplikaciji.',
            ),
            style: TextStyle(color: context.eq.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          for (final id in reportSteps) ...[
            Builder(
              builder: (context) {
                final complete = checks.any((c) => c['id'] == id && c['done'] == true);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    complete ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                    color: complete ? context.eq.accent : context.eq.faint,
                  ),
                  title: Text(
                    reportStepTitle(id, t),
                    style: TextStyle(fontSize: 13, color: context.eq.ink, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    complete ? t('Abgeschlossen', 'Zaključeno') : t('Noch offen', 'Še odprto'),
                    style: TextStyle(color: context.eq.muted, fontSize: 11),
                  ),
                  trailing: Icon(Icons.chevron_right, color: context.eq.faint, size: 18),
                  onTap: () => onStep(id),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => onStep(ready ? 'export' : next ?? 'profile'),
            icon: Icon(ready ? Icons.download_outlined : Icons.arrow_forward, size: 18),
            label: Text(
              ready ? t('Zu den Exporten', 'Na izvoze') : t('Nächsten Schritt bearbeiten', 'Uredi naslednji korak'),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportSectionStatus extends StatelessWidget {
  const ReportSectionStatus({
    super.key,
    required this.title,
    required this.done,
    required this.missing,
    required this.t,
    this.description,
  });
  final String title;
  final bool done;
  final List<Data> missing;
  final Tr t;
  final String? description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(color: context.eq.ink, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Pill(
              done ? t('Abgeschlossen', 'Zaključeno') : t('Noch offen', 'Še odprto'),
              color: context.eq.accent,
              icon: done ? Icons.check_circle_outline : Icons.schedule,
            ),
          ],
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(description!, style: TextStyle(color: context.eq.muted, fontSize: 12, height: 1.5)),
          ),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: EqCard(
              color: context.eq.bg,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('Noch zu ergänzen', 'Še je treba dopolniti'),
                    style: TextStyle(color: context.eq.ink, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  for (final item in missing)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.arrow_right, color: context.eq.accent, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reportRequirement(item, t),
                                  style: TextStyle(color: context.eq.ink, fontSize: 12, height: 1.5),
                                ),
                                if (item['article'] != null)
                                  Text(
                                    'Art. ${item['article']}',
                                    style: TextStyle(color: context.eq.muted, fontSize: 10, height: 1.7),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
