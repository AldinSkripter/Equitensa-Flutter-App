import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';

Future<void> _refresh(WidgetRef ref) async {
  ref.invalidate(payOverviewProvider);
  await ref.read(payOverviewProvider.future).catchError((_) => _none);
}

const _none = PayOverview(
  employees: 0,
  rawGapPercent: 0,
  adjustedGapPercent: 0,
  categories: [],
  steps: [],
);

class PayOverviewScreen extends ConsumerWidget {
  const PayOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = ref.watch(languageProvider);

    return AsyncBody<PayOverview>(
      value: ref.watch(payOverviewProvider),
      onRefresh: () => _refresh(ref),
      loading: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: const [
          Skeleton(height: 210, radius: 24),
          SizedBox(height: 16),
          Skeleton(height: 240),
        ],
      ),
      builder: (context, o) {
        final flagged = o.categories.where((c) => c.flagged).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF30223F), Color(0xFF4A2F7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Brand.ink.withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _Gauge(value: o.adjustedGapPercent),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('adjusted_gap'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${o.adjustedGapPercent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${s.t('raw_gap')}: ${o.rawGapPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          '${o.employees} ${s.t('employees')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionTitle(s.t('avg_pay_by_category')),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 20, 16, 14),
              child: Column(
                children: [
                  SizedBox(
                    height: 210,
                    child: _CategoryChart(categories: o.categories, lang: lang),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend(const Color(0xFFD65FA5), s.t('women')),
                      const SizedBox(width: 20),
                      _legend(Brand.violet, s.t('men')),
                    ],
                  ),
                ],
              ),
            ),
            SectionTitle(s.t('needs_attention')),
            if (flagged.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Brand.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.t('no_flags'))),
                  ],
                ),
              )
            else
              for (final c in flagged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CategoryTile(category: c),
                ),
            const SizedBox(height: 4),
            Text(
              s.t('threshold_note'),
              style: const TextStyle(
                color: Brand.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _legend(Color c, String t) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(t, style: const TextStyle(fontSize: 13, color: Brand.muted)),
    ],
  );
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: (value / 10).clamp(0, 1)),
    duration: const Duration(milliseconds: 1000),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _GaugePainter(
          v,
          value >= 5 ? const Color(0xFFFFB04D) : const Color(0xFF6FE3B0),
        ),
        child: Center(
          child: Icon(
            value >= 5 ? Icons.priority_high_rounded : Icons.check_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    ),
  );
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.15);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    final r = rect.deflate(8);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.categories, required this.lang});
  final List<JobCategory> categories;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final maxY =
        categories.fold<int>(
          0,
          (m, c) => math.max(m, math.max(c.avgMenCents, c.avgWomenCents)),
        ) *
        1.15;
    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Brand.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox.shrink()
                  : Text(
                      fmtMoneyShort(v.round(), lang),
                      style: const TextStyle(fontSize: 11, color: Brand.muted),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  categories[v.toInt()].name.substring(0, 3),
                  style: const TextStyle(fontSize: 11, color: Brand.muted),
                ),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < categories.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: categories[i].avgWomenCents.toDouble(),
                  width: 11,
                  color: const Color(0xFFD65FA5),
                  borderRadius: BorderRadius.circular(4),
                ),
                BarChartRodData(
                  toY: categories[i].avgMenCents.toDouble(),
                  width: 11,
                  color: Brand.violet,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class CategoryTile extends ConsumerWidget {
  const CategoryTile({super.key, required this.category});
  final JobCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final c = category;
    final color = c.flagged ? Brand.danger : Brand.success;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Pill(
                '${c.gapPercent.toStringAsFixed(1)}%',
                color: color,
                icon: c.flagged
                    ? Icons.warning_amber_rounded
                    : Icons.check_rounded,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${c.women} ${s.t('women')} · ${c.men} ${s.t('men')}',
            style: const TextStyle(color: Brand.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (c.gapPercent.abs() / 10).clamp(0, 1),
              backgroundColor: Brand.border,
              color: color,
            ),
          ),
          if (c.flagged) ...[
            const SizedBox(height: 10),
            Text(
              s.t('joint_assessment'),
              style: const TextStyle(fontSize: 12.5, color: Brand.muted),
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
    final s = S.of(context);
    return AsyncBody<PayOverview>(
      value: ref.watch(payOverviewProvider),
      onRefresh: () => _refresh(ref),
      isEmpty: (o) => o.categories.isEmpty,
      empty: StateMessage(
        icon: Icons.category_rounded,
        title: s.t('empty_categories_title'),
        body: s.t('empty_categories_body'),
      ),
      builder: (context, o) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        itemCount: o.categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => CategoryTile(category: o.categories[i]),
      ),
    );
  }
}

class PayReportScreen extends ConsumerWidget {
  const PayReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return AsyncBody<PayOverview>(
      value: ref.watch(payOverviewProvider),
      onRefresh: () => _refresh(ref),
      isEmpty: (o) => o.steps.isEmpty,
      empty: StateMessage(
        icon: Icons.fact_check_rounded,
        title: s.t('empty_report_title'),
        body: s.t('empty_report_body'),
      ),
      builder: (context, o) {
        final done = o.steps.where((e) => e.status == StepStatus.done).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('report_progress'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: done / o.steps.length,
                      backgroundColor: Brand.border,
                      color: Brand.violet,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$done / ${o.steps.length}',
                    style: const TextStyle(color: Brand.muted),
                  ),
                ],
              ),
            ),
            SectionTitle(s.t('workflow')),
            for (var i = 0; i < o.steps.length; i++)
              _StepTile(
                index: i,
                step: o.steps[i],
                last: i == o.steps.length - 1,
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(s.t('pdf_mock')))),
              icon: const Icon(Icons.download_rounded),
              label: Text(s.t('download_report')),
            ),
          ],
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.last,
  });
  final int index;
  final WorkflowStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (color, icon) = switch (step.status) {
      StepStatus.done => (Brand.success, Icons.check_rounded),
      StepStatus.active => (Brand.violet, Icons.more_horiz_rounded),
      StepStatus.todo => (Brand.border, null),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: step.status == StepStatus.todo
                        ? Colors.transparent
                        : color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: icon != null
                      ? Icon(icon, size: 18, color: Colors.white)
                      : Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Brand.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
                if (!last)
                  Expanded(child: Container(width: 2, color: Brand.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t(step.key),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    s.t('${step.key}_d'),
                    style: const TextStyle(
                      color: Brand.muted,
                      fontSize: 13,
                      height: 1.35,
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
}
