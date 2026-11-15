import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = ref.watch(languageProvider);
    final value = ref.watch(expensesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: value.hasError
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Brand.violet,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/receipt'),
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(s.t('scan_receipt')),
            ),
      body: AsyncBody<List<Expense>>(
        value: value,
        onRefresh: () async => ref.invalidate(expensesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: StateMessage(
          icon: Icons.account_balance_wallet_rounded,
          title: s.t('empty_expenses_title'),
          body: s.t('empty_expenses_body'),
          actionLabel: s.t('scan_receipt'),
          onAction: () => context.push('/receipt'),
        ),
        builder: (context, list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final e = list[i];
            return AppCard(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Brand.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon(e.category), color: Brand.warning),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.supplier,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${s.t('cat_${e.category}')} · ${fmtDate(e.date, lang)}',
                          style: const TextStyle(
                            color: Brand.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmtMoney(e.amountCents, lang),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        e.hasReceipt
                            ? Icons.attach_file_rounded
                            : Icons.report_gmailerrorred_rounded,
                        size: 16,
                        color: e.hasReceipt ? Brand.success : Brand.muted,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static IconData _icon(String c) => switch (c) {
    'software' => Icons.cloud_outlined,
    'travel' => Icons.train_rounded,
    'meals' => Icons.restaurant_rounded,
    _ => Icons.business_center_rounded,
  };
}
