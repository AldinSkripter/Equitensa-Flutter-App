import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../domain/models.dart';
import 'finance_common.dart';

class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.cents,
    required this.fmt,
    required this.style,
  });
  final int cents;
  final Fmt fmt;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: cents.toDouble()),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text(fmt.money(v.round()), style: style),
  );
}

class FinanceOverviewScreen extends ConsumerWidget {
  const FinanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    return FinanceView(
      loading: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: const [
          Skeleton(height: 60),
          SizedBox(height: 16),
          Skeleton(height: 300, radius: 26),
          SizedBox(height: 16),
          Skeleton(height: 120),
        ],
      ),
      builder: (context, snap) {
        final s = snap.state;
        final today = Fmt.today();
        final invoices = s.documents.where(
          (d) => d.isInvoice && d.status == 'issued',
        );
        final paid = invoices.fold<int>(0, (a, d) => a + d.paidCents);
        final open = invoices.where((d) => d.isUnpaid).fold<int>(0, (a, d) => a + d.outstandingCents);
        final overdue = invoices.where((d) => d.isOverdue(today)).fold<int>(0, (a, d) => a + d.outstandingCents);
        final expenses = s.expenses.fold<int>(0, (a, e) => a + e.amountCents);
        final drafts = s.documents.where((d) => d.isDraft).length;
        final share = paid + open == 0 ? 0.0 : paid / (paid + open);
        final recent = [...s.documents]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
          children: [
            PageHeader(
              kicker: 'Equitensa Finance / ${s.country.code}',
              title: t('Übersicht', 'Pregled'),
              subtitle: t(
                'Ein klarer Platz für Ihre Rechnungen und Belege.',
                'Jasno mesto za vaše račune in dokumente.',
              ),
            ).animate().fadeIn(duration: 400.ms),
            if (snap.stage == 'development') ...[
              const SizedBox(height: 16),
              NoticeBanner(
                t(
                  'Testmodus: Dokumente sind Entwürfe oder markierte Testdokumente. Direktversand, Bankanbindung und echte Abrechnung sind noch nicht freigegeben.',
                  'Testni način: dokumenti so osnutki ali označeni testni dokumenti. Neposredno pošiljanje, bančna povezava in obračun še niso sproščeni.',
                ),
              ),
            ],
            const SizedBox(height: 18),
            _Hero(
              share: share,
              paid: paid,
              open: open,
              fmt: fmt,
              t: t,
            ).animate().fadeIn(delay: 80.ms, duration: 500.ms).slideY(begin: 0.06, end: 0),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.18,
              children:
                  [
                        _Kpi(
                          label: t(
                            'Erfasste Zahlungen',
                            'Evidentirana plačila',
                          ),
                          cents: paid,
                          icon: LucideIcons.arrowDownLeft,
                          color: Eq.success,
                          fmt: fmt,
                        ),
                        _Kpi(
                          label: t('Offene Forderungen', 'Odprte terjatve'),
                          cents: open,
                          icon: LucideIcons.arrowUpRight,
                          color: Eq.violet,
                          fmt: fmt,
                          note: overdue > 0 ? '${fmt.money(overdue)} ${t('überfällig', 'zapadlo')}' : null,
                        ),
                        _Kpi(
                          label: t('Erfasste Ausgaben', 'Evidentirani stroški'),
                          cents: expenses,
                          icon: LucideIcons.wallet,
                          color: Eq.warning,
                          fmt: fmt,
                        ),
                        _CountKpi(
                          label: t('Dokumententwürfe', 'Osnutki dokumentov'),
                          count: drafts,
                          icon: LucideIcons.fileText,
                        ),
                      ].indexed
                      .map(
                        (e) => e.$2
                            .animate()
                            .fadeIn(
                              delay: (160 + e.$1 * 70).ms,
                              duration: 400.ms,
                            )
                            .slideY(begin: 0.1, end: 0),
                      )
                      .toList(),
            ),
            SectionTitle(
              t('Zuletzt bearbeitet', 'Nazadnje urejeno'),
              trailing: TextButton(
                onPressed: () => context.go('/finance/sales'),
                child: Text(t('Alle', 'Vsi')),
              ),
            ),
            if (recent.isEmpty)
              EqCard(
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.fileText,
                      size: 30,
                      color: Eq.violet,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t(
                        'Raum für den nächsten Auftrag.',
                        'Prostor za naslednje naročilo.',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(
                        'Erstellen Sie Ihren ersten Entwurf – Beträge berechnet der Server.',
                        'Ustvarite prvi osnutek – zneske izračuna strežnik.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Eq.muted),
                    ),
                  ],
                ),
              )
            else
              for (final d in recent.take(3))
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.share,
    required this.paid,
    required this.open,
    required this.fmt,
    required this.t,
  });
  final double share;
  final int paid, open;
  final Fmt fmt;
  final Tr t;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: Eq.heroGradient,
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: Eq.ink.withValues(alpha: 0.28),
          blurRadius: 34,
          offset: const Offset(0, 16),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFB9A2FF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Kicker(
              t('Ihr finanzieller Freiraum', 'Vaš finančni prostor'),
              color: const Color(0xFFC9B8FF),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Alles im Fluss.', 'Vse teče.'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                    ),
                  ),
                  Text(
                    t('Alles in Ihrer Hand.', 'Vse v vaših rokah.'),
                    style: const TextStyle(
                      color: Color(0xFF9B83F2),
                      fontSize: 25,
                      height: 1.15,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['serif'],
                    ),
                  ),
                ],
              ),
            ),
            ProgressRing(
              value: share,
              size: 112,
              caption: t('bezahlt', 'plačano'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountUp(
                    cents: paid,
                    fmt: fmt,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t('bezahlt', 'plačano'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CountUp(
                    cents: open,
                    fmt: fmt,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t('noch offen', 'še odprto'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.cents,
    required this.icon,
    required this.color,
    required this.fmt,
    this.note,
  });
  final String label;
  final int cents;
  final IconData icon;
  final Color color;
  final Fmt fmt;
  final String? note;

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
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Eq.muted,
                  height: 1.25,
                ),
              ),
            ),
            Icon(icon, size: 16, color: color),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CountUp(
            cents: cents,
            fmt: fmt,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.8,
              color: Eq.ink2,
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            style: const TextStyle(
              fontSize: 11.5,
              color: Eq.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
}

class _CountKpi extends StatelessWidget {
  const _CountKpi({
    required this.label,
    required this.count,
    required this.icon,
  });
  final String label;
  final int count;
  final IconData icon;

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
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Eq.muted,
                  height: 1.25,
                ),
              ),
            ),
            Icon(icon, size: 16, color: Eq.violet),
          ],
        ),
        const Spacer(),
        Text(
          count.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
            color: Eq.ink2,
          ),
        ),
      ],
    ),
  );
}

/// One document row, shared by Overview and Sales.
class DocTile extends ConsumerWidget {
  const DocTile({super.key, required this.doc});
  final FinDoc doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    final st = statusOf(t, doc);
    return EqCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/finance/document/${doc.id}'),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Eq.violetSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              doc.isOffer ? LucideIcons.fileCheck : LucideIcons.fileText,
              size: 20,
              color: Eq.violet,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Eq.ink2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${doc.number ?? t('Entwurf', 'Osnutek')} · ${doc.issueDate} · ${kindLabel(t, doc.kind)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Eq.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt.money(doc.grossCents),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.3,
                  color: Eq.ink2,
                ),
              ),
              const SizedBox(height: 5),
              Pill(st.label, color: st.color),
            ],
          ),
        ],
      ),
    );
  }
}
