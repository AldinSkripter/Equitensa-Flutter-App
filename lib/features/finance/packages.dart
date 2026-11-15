import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';

class PackagesScreen extends ConsumerWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = ref.watch(languageProvider);
    final company = ref.watch(sessionProvider);
    final current = company?.plan;
    final country = company?.country;

    String name(FinancePlan p) => switch (p) {
      FinancePlan.start => country == Country.si ? 'Računi' : 'Rechnungen',
      FinancePlan.business => 'Business',
      FinancePlan.pro => 'Pro',
    };

    List<(String, bool)> features(FinancePlan p) => [
      (s.t('f_invoices'), true),
      (s.t('f_pdf_xml'), true),
      (s.t('f_expenses'), p.hasExpenses),
      (s.t('f_ocr'), p.hasExpenses),
      (s.t('f_bank'), p.hasExpenses),
      (s.t('f_recurring'), p.hasRecurring),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('packages'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Brand.violet.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Brand.violet,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.t('packages_notice'),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final p in FinancePlan.values) ...[
            _PlanCard(
              title: name(p),
              price: fmtMoney(p.monthlyNetCents, lang),
              perMonth: s.t('per_month_net'),
              seats: '${p.seats} ${s.t(p.seats == 1 ? 'seat' : 'seats')}',
              minTerm: s.t('min_term'),
              current: p == current,
              features: features(p),
              actionLabel: s.t('demo_select'),
              onSelect: p == current
                  ? null
                  : () async {
                      try {
                        await ref.read(sessionProvider.notifier).setPlan(p);
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.perMonth,
    required this.seats,
    required this.minTerm,
    required this.current,
    required this.features,
    required this.actionLabel,
    required this.onSelect,
  });

  final String title, price, perMonth, seats, minTerm, actionLabel;
  final bool current;
  final List<(String, bool)> features;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: current ? Brand.violet : Brand.border,
          width: current ? 2 : 1,
        ),
        boxShadow: Brand.softShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (current)
                Pill(
                  s.t('current_plan'),
                  color: Brand.violet,
                  icon: Icons.check_rounded,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Brand.violet,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  perMonth,
                  style: const TextStyle(color: Brand.muted, fontSize: 13),
                ),
              ),
            ],
          ),
          Text(
            '$seats · $minTerm',
            style: const TextStyle(color: Brand.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    f.$2
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: f.$2 ? Brand.success : Brand.border,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.$1,
                      style: TextStyle(
                        color: f.$2 ? Brand.ink : Brand.muted,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (onSelect != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onSelect, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}
