import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/ui.dart';
import '../workspace/workspace_widgets.dart';

class PayAnalysisDetailScreen extends ConsumerWidget {
  const PayAnalysisDetailScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref), fmt = fmtOf(ref);
    return RemotePage(
      title: t('Alle Kennzahlen', 'Vsi kazalniki'),
      load: (ref) => ref.read(apiClientProvider).getJson('/analysis?year=${ref.read(payYearProvider)}'),
      builder: (context, ref, d, reload) {
        final analysis = object(d['analysis']);
        const metrics = {
          'mean_gap': ('Durchschnittliche Lücke (stündlich)', 'Povprečna vrzel (urno)'),
          'median_gap': ('Median-Lücke (stündlich)', 'Mediana vrzeli (urno)'),
          'base_gap': ('Grundentgelt-Lücke', 'Vrzel osnovnega plačila'),
          'variable_gap': ('Variable Lücke', 'Variabilna vrzel'),
          'median_variable_gap': ('Median variable Lücke', 'Mediana variabilne vrzeli'),
          'annual_mean_gap': ('Durchschnittliche Jahreslücke', 'Povprečna letna vrzel'),
          'annual_median_gap': ('Median Jahreslücke', 'Mediana letne vrzeli'),
          'annual_base_gap': ('Grundentgelt jährlich', 'Letno osnovno plačilo'),
          'annual_variable_gap': ('Variable Lücke jährlich', 'Letna variabilna vrzel'),
          'annual_median_variable_gap': ('Median variable Lücke jährlich', 'Mediana letne variabilne vrzeli'),
          'male_variable_receivers': ('Männer mit variabler Vergütung', 'Moški z variabilnim plačilom'),
          'female_variable_receivers': ('Frauen mit variabler Vergütung', 'Ženske z variabilnim plačilom'),
        };
        List<Widget> figures(Data value) => [
          for (final metric in metrics.entries)
            entryCard(
              context,
              t(metric.value.$1, metric.value.$2),
              value[metric.key] is num
                  ? fmt.percent(value[metric.key] as num)
                  : t('Geschützt / nicht vergleichbar', 'Zaščiteno / ni primerljivo'),
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const YearSelector(),
            const SizedBox(height: 20),
            NoticeBanner(
              '${analysis['count'] ?? 0} · ${t('Beschäftigte', 'zaposlenih')}\n${analysis['methodology'] ?? ''}',
            ),
            const SizedBox(height: 16),
            ...figures(analysis),
            for (final key in ['quartiles', 'annual_quartiles']) ...[
              SectionTitle(
                key == 'quartiles'
                    ? t('Stundenentgelt · Quartile', 'Urno plačilo · kvartili')
                    : t('Jahresentgelt · Quartile', 'Letno plačilo · kvartili'),
              ),
              for (final q in records(analysis[key]))
                entryCard(
                  context,
                  'Q${q['quartile']} · ${q['count']}',
                  q['suppressed'] == true
                      ? t('Geschützt', 'Zaščiteno')
                      : '${t('Männer', 'Moški')}: ${q['male_percent']} % · ${t('Frauen', 'Ženske')}: ${q['female_percent']} %',
                ),
            ],
            SectionTitle(t('Kategorien', 'Kategorije')),
            for (final group in records(analysis['groups']))
              ExpansionTile(
                title: Text('${group['category']}'),
                subtitle: Text(
                  '${group['count']} · ${group['review_required'] == true ? t('Prüfung erforderlich', 'Potreben pregled') : ''}',
                ),
                children: figures(group),
              ),
            const SizedBox(height: 16),
            NoticeBanner('${d['scheduleBasis'] ?? ''}\n${object(d['schedule'])['first_due'] ?? ''}'),
          ],
        );
      },
    );
  }
}

class WorkspaceBrandScreen extends ConsumerWidget {
  const WorkspaceBrandScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return RemotePage(
      title: t('Unternehmensauftritt', 'Predstavitev podjetja'),
      load: (ref) => ref.read(apiClientProvider).getJson('/company/brand'),
      builder: (context, ref, d, reload) {
        final brand = object(d['brand']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ('${brand['logo'] ?? ''}'.startsWith('data:image/'))
              SizedBox(height: 100, child: Image.memory(base64Decode(brand['logo'].toString().split(',').last))),
            entryCard(
              context,
              '${brand['displayName']}',
              '',
              onTap: () async {
                await editData(
                  context,
                  title: t('Anzeigename', 'Prikazno ime'),
                  initial: brand,
                  fields: const [Input('displayName', 'Anzeigename', 'Prikazno ime', required: true)],
                  save: (v) async {
                    await ref.read(apiClientProvider).postJson('/company/brand', v);
                    ref.invalidate(workspaceBrandProvider);
                  },
                );
                reload();
              },
            ),
            AsyncAction(
              label: t('Logo hochladen', 'Naloži logotip'),
              action: () async {
                final file = await pickDocument(maxBytes: 250000);
                if (file == null) return;
                final png = file.bytes.take(4).join(',') == '137,80,78,71';
                final jpeg = file.bytes.length > 2 && file.bytes[0] == 255 && file.bytes[1] == 216;
                if (!png && !jpeg) throw StateError('PNG / JPEG erforderlich');
                await ref.read(apiClientProvider).postJson('/company/brand', {
                  ...brand,
                  'logo': 'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(file.bytes)}',
                });
                ref.invalidate(workspaceBrandProvider);
                reload();
              },
            ),
            const SizedBox(height: 12),
            AsyncAction(
              label: t('Logo entfernen', 'Odstrani logotip'),
              action: () async {
                await ref.read(apiClientProvider).postJson('/company/brand', {...brand, 'logo': ''});
                ref.invalidate(workspaceBrandProvider);
                reload();
              },
            ),
          ],
        );
      },
    );
  }
}
