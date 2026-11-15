import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../domain/models.dart';
import 'finance_common.dart';
import 'finance_overview.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _filter = 'all';
  String _sort = 'newest';
  String _query = '';

  bool _matches(FinDoc d, String f, String today) => switch (f) {
    'draft' => d.isDraft,
    'offers' => d.isOffer,
    'open' => d.isUnpaid,
    'overdue' => d.isOverdue(today),
    'paid' => d.isInvoice && d.status == 'issued' && d.paidCents >= d.grossCents,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    return FinanceView(
      builder: (context, snap) {
        final docs = snap.state.documents;
        final today = Fmt.today();
        final q = _query.toLowerCase();
        final shown =
            docs
                .where(
                  (d) =>
                      _matches(d, _filter, today) &&
                      '${d.customer.name} ${d.number ?? ''} ${d.lines.map((l) => l.description).join(' ')}'
                          .toLowerCase()
                          .contains(q),
                )
                .toList()
              ..sort(
                (a, b) => switch (_sort) {
                  'amount' => b.grossCents.compareTo(a.grossCents),
                  'due' => a.dueDate.compareTo(b.dueDate),
                  _ => b.createdAt.compareTo(a.createdAt),
                },
              );
        final open = docs.where((d) => d.isUnpaid).fold<int>(0, (a, d) => a + d.outstandingCents);
        final over = docs.where((d) => d.isOverdue(today)).fold<int>(0, (a, d) => a + d.outstandingCents);
        final paid = docs.where((d) => d.isInvoice && d.status == 'issued').fold<int>(0, (a, d) => a + d.paidCents);

        final filters = [
          ('all', t('Alle', 'Vsi')),
          ('draft', t('Entwürfe', 'Osnutki')),
          ('offers', t('Angebote', 'Ponudbe')),
          ('open', t('Offen', 'Odprto')),
          ('overdue', t('Überfällig', 'Zapadlo')),
          ('paid', t('Bezahlt', 'Plačano')),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
          children: [
            PageHeader(
              kicker: 'Document Center',
              title: t(
                'Jeder Auftrag.\nJeder nächste Schritt.',
                'Vsako naročilo.\nVsak naslednji korak.',
              ),
              subtitle: t(
                'Angebote, Entwürfe und Zahlungseingänge in einem klaren Arbeitsablauf.',
                'Ponudbe, osnutki in prejeta plačila v jasnem poteku dela.',
              ),
            ),
            const SizedBox(height: 18),
            EqButton(
              label: t('Dokument erstellen', 'Ustvari dokument'),
              icon: LucideIcons.plus,
              onPressed: () => context.push('/finance/compose?kind=invoice'),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _Stat(
                  t('Dokumente', 'Dokumenti'),
                  '${docs.length}',
                  LucideIcons.fileText,
                ),
                _Stat(
                  t('Offener Betrag', 'Odprt znesek'),
                  fmt.money(open),
                  LucideIcons.clock,
                ),
                _Stat(
                  t('Überfällig', 'Zapadlo'),
                  fmt.money(over),
                  LucideIcons.arrowUpRight,
                  danger: over > 0,
                ),
                _Stat(
                  t('Erfasste Zahlungen', 'Evidentirana plačila'),
                  fmt.money(paid),
                  LucideIcons.check,
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilterTabs(
              items: [
                for (final f in filters)
                  (
                    id: f.$1,
                    label: f.$2,
                    count: docs.where((d) => _matches(d, f.$1, today)).length,
                  ),
              ],
              selected: _filter,
              onSelect: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: t(
                        'Kunde, Nummer oder Leistung suchen',
                        'Poišči stranko, številko ali storitev',
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        size: 18,
                        color: Eq.faint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  onSelected: (v) => setState(() => _sort = v),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'newest',
                      child: Text(t('Neueste zuerst', 'Najnovejši najprej')),
                    ),
                    PopupMenuItem(
                      value: 'due',
                      child: Text(t('Nach Fälligkeit', 'Po zapadlosti')),
                    ),
                    PopupMenuItem(
                      value: 'amount',
                      child: Text(t('Höchster Betrag', 'Najvišji znesek')),
                    ),
                  ],
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDCD5E8)),
                    ),
                    child: const Icon(
                      LucideIcons.arrowDownUp,
                      size: 18,
                      color: Eq.ink2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (shown.isEmpty)
              StateMessageInline(
                icon: LucideIcons.fileText,
                title: t(
                  'Raum für den nächsten Auftrag.',
                  'Prostor za naslednje naročilo.',
                ),
                body: t(
                  'Keine Dokumente für diese Auswahl. Erstellen Sie einen Entwurf oder ändern Sie den Filter.',
                  'Za ta izbor ni dokumentov. Ustvarite osnutek ali spremenite filter.',
                ),
              )
            else
              for (final d in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DocTile(doc: d),
                ),
          ],
        );
      },
    );
  }
}

class StateMessageInline extends StatelessWidget {
  const StateMessageInline({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Eq.violetSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Eq.violet, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: Eq.ink2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Eq.muted, height: 1.5),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, {this.danger = false});
  final String label;
  final String value;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => EqCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Eq.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(icon, size: 14, color: danger ? Eq.danger : Eq.faint),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
              color: danger ? Eq.danger : Eq.ink2,
            ),
          ),
        ),
      ],
    ),
  );
}
