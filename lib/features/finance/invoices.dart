import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import 'finance_overview.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  InvoiceStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final value = ref.watch(invoicesProvider);

    Future<void> refresh() async {
      ref.invalidate(invoicesProvider);
      await ref.read(invoicesProvider.future).catchError((_) => <Invoice>[]);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Brand.violet,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/invoice/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.t('new_invoice')),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              children: [
                _chip(s.t('filter_all'), null),
                for (final st in InvoiceStatus.values)
                  _chip(s.t('st_${st.name}'), st),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<List<Invoice>>(
              value: value,
              onRefresh: refresh,
              isEmpty: (l) => _apply(l).isEmpty,
              empty: StateMessage(
                icon: Icons.receipt_long_rounded,
                title: s.t('empty_invoices_title'),
                body: s.t('empty_invoices_body'),
                actionLabel: s.t('new_invoice'),
                onAction: () => context.push('/invoice/new'),
              ),
              builder: (context, list) {
                final shown = _apply(list);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => InvoiceTile(invoice: shown[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Invoice> _apply(List<Invoice> l) =>
      _filter == null ? l : l.where((i) => i.status == _filter).toList();

  Widget _chip(String label, InvoiceStatus? st) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == st,
      showCheckmark: false,
      selectedColor: Brand.violet,
      backgroundColor: Brand.surface,
      side: const BorderSide(color: Brand.border),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: _filter == st ? Colors.white : Brand.ink,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      onSelected: (_) => setState(() => _filter = st),
    ),
  );
}
