import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import 'conflict.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _busy = false;

  Future<void> _markPaid(Invoice inv) async {
    setState(() => _busy = true);
    try {
      final rev = await ref.latestRevision();
      await ref.read(repositoryProvider).markPaid(inv.id, revision: rev);
      ref.refreshFinanceData();
    } on VersionConflictException {
      if (!mounted) return;
      ref.refreshFinanceData();
      await showConflictDialog(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = ref.watch(languageProvider);
    final company = ref.watch(sessionProvider);
    final value = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('invoice'))),
      body: AsyncBody<List<Invoice>>(
        value: value,
        onRefresh: () async => ref.invalidate(invoicesProvider),
        builder: (context, list) {
          final inv = list.where((i) => i.id == widget.id).firstOrNull;
          if (inv == null) {
            return StateMessage(
              icon: Icons.search_off_rounded,
              title: s.t('not_found'),
              body: s.t('not_found_body'),
            );
          }
          final canPay =
              inv.status == InvoiceStatus.issued ||
              inv.status == InvoiceStatus.overdue;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  StatusPill(inv.status),
                  const Spacer(),
                  Text(
                    s.t('server_document'),
                    style: const TextStyle(color: Brand.muted, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: Brand.muted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Paper(inv: inv, company: company!, lang: lang),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(s.t('pdf_mock')))),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(s.t('share_pdf')),
              ),
              if (canPay) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _markPaid(inv),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(s.t('mark_paid')),
                ),
              ],
              if (inv.status == InvoiceStatus.draft) ...[
                const SizedBox(height: 12),
                Text(
                  s.t('draft_issue_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Brand.muted, fontSize: 13),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Document preview. In production this mirrors the backend document model; the phone
/// only renders what the server returned.
class _Paper extends StatelessWidget {
  const _Paper({required this.inv, required this.company, required this.lang});
  final Invoice inv;
  final Company company;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const tiny = TextStyle(fontSize: 12, color: Brand.muted);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Brand.border),
        boxShadow: Brand.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${company.city}, ${company.country.code}',
                      style: tiny,
                    ),
                  ],
                ),
              ),
              Text(
                s.t('invoice').toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Brand.violet,
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Text(s.t('bill_to'), style: tiny),
          const SizedBox(height: 2),
          Text(
            inv.contact.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(inv.contact.city, style: tiny),
          if (inv.contact.vatId.isNotEmpty)
            Text(inv.contact.vatId, style: tiny),
          const SizedBox(height: 16),
          Row(
            children: [
              _meta(s.t('number'), inv.number ?? '—'),
              _meta(s.t('issue_date'), fmtDate(inv.issueDate, lang)),
              _meta(s.t('due_date'), fmtDate(inv.dueDate, lang)),
            ],
          ),
          const SizedBox(height: 18),
          for (final l in inv.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.description,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${l.quantity} ${l.unit} × ${l.unitPrice} · ${l.rate}%',
                          style: tiny,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 28),
          _row(s.t('net'), fmtMoney(inv.totals.netCents, lang)),
          _row(s.t('vat'), fmtMoney(inv.totals.taxCents, lang)),
          const SizedBox(height: 6),
          _row(s.t('gross'), fmtMoney(inv.totals.grossCents, lang), bold: true),
        ],
      ),
    );
  }

  Widget _meta(String l, String v) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l, style: const TextStyle(fontSize: 11, color: Brand.muted)),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _row(String l, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(
          l,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
            fontSize: bold ? 17 : 14,
          ),
        ),
        const Spacer(),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            fontSize: bold ? 20 : 14,
            color: bold ? Brand.violet : Brand.ink,
          ),
        ),
      ],
    ),
  );
}
