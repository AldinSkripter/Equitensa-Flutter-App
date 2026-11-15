import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../domain/models.dart';
import '../finance/sales_screen.dart';

Future<void> _refresh(WidgetRef ref) async {
  ref.invalidate(payAnalysisProvider);
  ref.invalidate(payReadinessProvider);
  try {
    await ref.read(payAnalysisProvider.future);
  } catch (_) {}
}

class PayOverviewScreen extends ConsumerWidget {
  const PayOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    final analysis = ref.watch(payAnalysisProvider);
    final readiness = ref.watch(payReadinessProvider).value;
    final year = ref.watch(payYearProvider);

    return AsyncView<PayAnalysis>(
      value: analysis,
      onRefresh: () => _refresh(ref),
      loading: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: const [
          Skeleton(height: 60),
          SizedBox(height: 16),
          Skeleton(height: 260, radius: 26),
          SizedBox(height: 16),
          Skeleton(height: 140),
        ],
      ),
      builder: (context, a) {
        final flagged = a.groups.where((g) => g.reviewRequired).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
          children: [
            PageHeader(
              kicker: 'Pay Transparency / ${ref.watch(countryProvider).code}',
              title: t('Klarheit beginnt hier.', 'Jasnost se začne tukaj.'),
              subtitle: t(
                'Ihr Bericht, Ihre Daten und die nächsten Schritte – auf einen Blick.',
                'Vaše poročilo, vaši podatki in naslednji koraki – na prvi pogled.',
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: Eq.heroGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: context.eq.ink.withValues(alpha: 0.28),
                    blurRadius: 34,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '$year · ${t('ARBEITSBERICHT', 'DELOVNO POROČILO')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(
                                'Ihre Daten sind der Anfang.',
                                'Vaši podatki so začetek.',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t(
                                'Wir berechnen. Sie prüfen. Gemeinsam entsteht ein klarer Bericht.',
                                'Mi izračunamo. Vi preverite. Skupaj nastane jasno poročilo.',
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ProgressRing(
                        value: (readiness?.percent ?? 0) / 100,
                        size: 108,
                        caption: t('vorbereitet', 'pripravljeno'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  EqButton(
                    label: t(
                      'Nächsten Schritt öffnen',
                      'Odpri naslednji korak',
                    ),
                    trailingIcon: LucideIcons.arrowRight,
                    onPressed: () => context.go('/pay/report'),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children:
                  [
                        _Kpi(
                          label: t(
                            'Beschäftigte im Datenstand',
                            'Zaposleni v podatkih',
                          ),
                          value: '${a.count}',
                          note:
                              '${a.female} ${t('Frauen', 'žensk')} · ${a.male} ${t('Männer', 'moških')} · ${a.other} ${t('Andere', 'drugi')}',
                          icon: LucideIcons.users,
                        ),
                        _Kpi(
                          label: t(
                            'Mittlere Entgeltlücke',
                            'Povprečna razlika',
                          ),
                          value: a.suppressed ? '—' : fmt.percent(a.meanGap),
                          note: t(
                            'Gesamtvergütung · pro Stunde',
                            'Skupno plačilo · na uro',
                          ),
                          icon: LucideIcons.chartNoAxesCombined,
                        ),
                        _Kpi(
                          label: t('Mediane Entgeltlücke', 'Mediana razlike'),
                          value: a.suppressed ? '—' : fmt.percent(a.medianGap),
                          note: t(
                            'Gesamtvergütung · pro Stunde',
                            'Skupno plačilo · na uro',
                          ),
                          icon: LucideIcons.scale,
                        ),
                        _Kpi(
                          label: t(
                            'Kategorien zur Prüfung',
                            'Kategorije za pregled',
                          ),
                          value: '${a.reviewCount}',
                          note: t(
                            'Ab 5 % · keine automatische Diskriminierungsfeststellung',
                            'Od 5 % · brez samodejne ugotovitve diskriminacije',
                          ),
                          icon: LucideIcons.circleAlert,
                          accent: a.reviewCount > 0 ? Eq.warning : Eq.success,
                        ),
                      ].indexed
                      .map(
                        (e) => e.$2
                            .animate()
                            .fadeIn(
                              delay: (120 + e.$1 * 70).ms,
                              duration: 400.ms,
                            )
                            .slideY(begin: 0.1, end: 0),
                      )
                      .toList(),
            ),
            SectionTitle(
              t('Entgeltlücke je Kategorie', 'Razlika po kategorijah'),
            ),
            EqCard(
              padding: const EdgeInsets.fromLTRB(8, 22, 16, 12),
              child: SizedBox(
                height: 220,
                child: _GapChart(groups: a.groups, fmt: fmt),
              ),
            ),
            SectionTitle(t('Handlungsbedarf', 'Zahteva ukrepanje')),
            if (flagged.isEmpty)
              EqCard(
                child: Row(
                  children: [
                    const Icon(LucideIcons.circleCheck, color: Eq.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t(
                          'Keine Kategorie überschreitet die 5-%-Schwelle.',
                          'Nobena kategorija ne presega praga 5 %.',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final g in flagged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GroupTile(group: g),
                ),
            const SizedBox(height: 4),
            Text(
              t(
                'Berechnung und Berichte erstellt ausschließlich das Backend – die App zeigt die Ergebnisse.',
                'Izračune in poročila pripravi izključno strežnik – aplikacija prikaže rezultate.',
              ),
              style: TextStyle(
                color: context.eq.faint,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    this.accent = Eq.violet,
  });
  final String label, value, note;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => EqCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.eq.muted,
                  height: 1.25,
                ),
              ),
            ),
            Icon(icon, size: 16, color: accent),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
              color: context.eq.ink2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          note,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: context.eq.muted, height: 1.3),
        ),
      ],
    ),
  );
}

class _GapChart extends StatelessWidget {
  const _GapChart({required this.groups, required this.fmt});
  final List<PayGroup> groups;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final shown = groups.where((g) => !g.suppressed).take(8).toList();
    if (shown.isEmpty) return const Center(child: Text('—'));
    final maxY = (shown.map((g) => g.gap.abs()).reduce((a, b) => a > b ? a : b) * 1.25).clamp(6.0, 100.0);
    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: v == 5 ? Eq.warning.withValues(alpha: 0.5) : context.eq.lineSoft,
            strokeWidth: v == 5 ? 1.4 : 1,
            dashArray: v == 5 ? [5, 4] : null,
          ),
          horizontalInterval: 5,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 5,
              getTitlesWidget: (v, meta) => Text(
                '${v.toInt()} %',
                style: TextStyle(fontSize: 10.5, color: context.eq.muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) {
                final name = shown[v.toInt()].category;
                final short = name.split(' · ').last;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    short.length > 5 ? short.substring(0, 5) : short,
                    style: TextStyle(fontSize: 10.5, color: context.eq.muted),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, _, rod, _) => BarTooltipItem(
              '${shown[g.x].category}\n${fmt.percent(rod.toY)}',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < shown.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: shown[i].gap.abs(),
                  width: 20,
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(
                    colors: shown[i].reviewRequired
                        ? [const Color(0xFFFFB347), const Color(0xFFE0801A)]
                        : [const Color(0xFFA48BFF), Eq.violet],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class GroupTile extends ConsumerWidget {
  const GroupTile({super.key, required this.group});
  final PayGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    final g = group;
    final color = g.suppressed
        ? context.eq.muted
        : g.reviewRequired
        ? Eq.warning
        : Eq.success;
    return EqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.category,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: context.eq.ink2,
                  ),
                ),
              ),
              Pill(
                g.suppressed ? t('Unterdrückt', 'Skrito') : fmt.percent(g.gap),
                color: color,
                icon: g.suppressed
                    ? LucideIcons.eyeOff
                    : g.reviewRequired
                    ? LucideIcons.triangleAlert
                    : LucideIcons.check,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${g.count} ${t('Beschäftigte', 'zaposlenih')} · ${g.female} ${t('Frauen', 'žensk')} · ${g.male} ${t('Männer', 'moških')}',
            style: TextStyle(color: context.eq.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: g.suppressed ? 0 : (g.gap.abs() / 10).clamp(0, 1),
              backgroundColor: context.eq.lineSoft,
              color: color,
            ),
          ),
          if (g.suppressed) ...[
            const SizedBox(height: 8),
            Text(
              t(
                'Gruppe zu klein – Kennzahlen werden zum Schutz kleiner Gruppen nicht angezeigt.',
                'Skupina je premajhna – kazalniki se zaradi zaščite majhnih skupin ne prikažejo.',
              ),
              style: TextStyle(
                fontSize: 12.5,
                color: context.eq.muted,
                height: 1.4,
              ),
            ),
          ] else if (g.reviewRequired) ...[
            const SizedBox(height: 8),
            Text(
              t(
                'Ab 5 % ohne Begründung ist eine gemeinsame Entgeltbewertung erforderlich.',
                'Od 5 % brez utemeljitve je potrebna skupna ocena plač.',
              ),
              style: TextStyle(
                fontSize: 12.5,
                color: context.eq.muted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PayCategoriesScreen extends ConsumerWidget {
  const PayCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return AsyncView<PayAnalysis>(
      value: ref.watch(payAnalysisProvider),
      onRefresh: () => _refresh(ref),
      builder: (context, a) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
        children: [
          PageHeader(
            kicker: 'Pay Transparency / ${ref.watch(countryProvider).code}',
            title: t('Kategorien', 'Kategorije'),
            subtitle: t(
              'Vergleichbare Gruppen mit Entgeltlücke und Prüfhinweisen.',
              'Primerljive skupine z razliko v plačah in opozorili za pregled.',
            ),
          ),
          const SizedBox(height: 18),
          EqButton(
            label: t('Kategorien und Bewertung bearbeiten', 'Uredi kategorije in vrednotenje'),
            kind: BtnKind.secondary,
            onPressed: () => context.push('/pay/report'),
          ),
          const SizedBox(height: 16),
          if (a.groups.isEmpty)
            StateMessageInline(
              icon: LucideIcons.layers,
              title: t('Keine Kategorien', 'Ni kategorij'),
              body: t(
                'Importieren Sie Gehaltsdaten, um Vergleichskategorien zu bilden.',
                'Uvozite podatke o plačah v spletu za oblikovanje primerljivih kategorij.',
              ),
            )
          else
            for (final g in a.groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GroupTile(group: g),
              ),
        ],
      ),
    );
  }
}
