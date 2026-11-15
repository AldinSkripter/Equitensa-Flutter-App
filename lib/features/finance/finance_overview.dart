import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';

class FinanceOverviewScreen extends ConsumerWidget {
  const FinanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = ref.watch(languageProvider);
    final overview = ref.watch(financeOverviewProvider);
    final invoices = ref.watch(invoicesProvider);
    final plan = ref.watch(sessionProvider)?.plan;

    Future<void> refresh() async {
      ref.refreshFinanceData();
      await ref.read(financeOverviewProvider.future).catchError((_) => _empty);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncBody<FinanceOverview>(
        value: overview,
        onRefresh: refresh,
        loading: const _OverviewSkeleton(),
        builder: (context, o) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _HeroCard(overview: o, lang: lang),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Kpi(
                    label: s.t('kpi_paid'),
                    value: fmtMoney(o.paidMonthCents, lang),
                    icon: Icons.check_circle_rounded,
                    color: Brand.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Kpi(
                    label: s.t('kpi_expenses'),
                    value: fmtMoney(o.expensesMonthCents, lang),
                    icon: Icons.north_east_rounded,
                    color: Brand.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SectionTitle(s.t('quick_actions')),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Action(
                      icon: Icons.note_add_rounded,
                      label: s.t('new_invoice'),
                      onTap: () => context.push('/invoice/new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Action(
                      icon: Icons.person_add_alt_1_rounded,
                      label: s.t('new_customer'),
                      onTap: () => context.push('/customer/new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Action(
                      icon: Icons.document_scanner_rounded,
                      label: s.t('scan_receipt'),
                      locked: plan?.hasExpenses == false,
                      onTap: () => context.push(
                        plan?.hasExpenses == false ? '/packages' : '/receipt',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SectionTitle(s.t('revenue_6m')),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 22, 16, 12),
              child: SizedBox(
                height: 170,
                child: _RevenueChart(values: o.monthlyRevenueCents, lang: lang),
              ),
            ),
            SectionTitle(
              s.t('recent_invoices'),
              trailing: TextButton(
                onPressed: () => context.go('/finance/invoices'),
                child: Text(s.t('see_all')),
              ),
            ),
            ...invoices.maybeWhen(
              data: (list) => [
                for (final i in list.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InvoiceTile(invoice: i),
                  ),
              ],
              orElse: () => const [Skeleton(height: 76)],
            ),
          ],
        ),
      ),
    );
  }

  static const _empty = FinanceOverview(
    openCents: 0,
    overdueCents: 0,
    paidMonthCents: 0,
    expensesMonthCents: 0,
    monthlyRevenueCents: [],
    revision: 0,
  );
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    children: const [
      Skeleton(height: 150, radius: 24),
      SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: Skeleton(height: 90)),
          SizedBox(width: 12),
          Expanded(child: Skeleton(height: 90)),
        ],
      ),
      SizedBox(height: 16),
      Skeleton(height: 200),
    ],
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.overview, required this.lang});
  final FinanceOverview overview;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('open_receivables'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: overview.openCents + overview.overdueCents.toDouble(),
            ),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              fmtMoney(v.round(), lang),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(
                '${s.t('st_issued')} ${fmtMoney(overview.openCents, lang)}',
                color: Colors.white,
              ),
              if (overview.overdueCents > 0)
                Pill(
                  '${s.t('st_overdue')} ${fmtMoney(overview.overdueCents, lang)}',
                  color: const Color(0xFFFF8FA3),
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Brand.muted, fontSize: 13)),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Brand.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Brand.violet),
            ),
            if (locked)
              const Positioned(
                right: -6,
                top: -6,
                child: Icon(Icons.lock_rounded, size: 16, color: Brand.muted),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.values, required this.lang});
  final List<int> values;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      for (var i = values.length - 1; i >= 0; i--)
        DateTime(now.year, now.month - i),
    ];
    const names = {
      'de': ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'],
      'sl': ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'],
      'en': ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'],
    };
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  (names[lang] ?? names['en']!)[months[v.toInt()].month - 1],
                  style: const TextStyle(color: Brand.muted, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, _, rod, _) => BarTooltipItem(
              fmtMoney(rod.toY.round(), lang),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
                  width: 22,
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: i == values.length - 1
                        ? [Brand.violet, const Color(0xFFA25CF5)]
                        : [
                            Brand.violet.withValues(alpha: 0.35),
                            Brand.violet.withValues(alpha: 0.2),
                          ],
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

class InvoiceTile extends ConsumerWidget {
  const InvoiceTile({super.key, required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = ref.watch(languageProvider);
    return AppCard(
      onTap: () => context.push('/invoice/${invoice.id}'),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Brand.violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Brand.violet),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${invoice.number ?? s.t('st_draft')} · ${fmtDate(invoice.dueDate, lang)}',
                  style: const TextStyle(color: Brand.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtMoney(invoice.totals.grossCents, lang),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              StatusPill(invoice.status),
            ],
          ),
        ],
      ),
    );
  }
}
