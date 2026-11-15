import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'finance_common.dart';
import 'sales_screen.dart';

const expenseCategories = ['software', 'office', 'travel', 'services', 'other'];

String categoryLabel(Tr t, String c) => switch (c) {
  'software' => t('Software', 'Programska oprema'),
  'office' => t('Büro', 'Pisarna'),
  'travel' => t('Reisen', 'Potovanja'),
  'services' => t('Dienstleistungen', 'Storitve'),
  _ => t('Sonstiges', 'Drugo'),
};

IconData categoryIcon(String c) => switch (c) {
  'software' => LucideIcons.cloud,
  'office' => LucideIcons.briefcase,
  'travel' => LucideIcons.train,
  'services' => LucideIcons.handshake,
  _ => LucideIcons.receipt,
};

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    return FinanceView(
      builder: (context, snap) {
        if (!snap.hasFeature('expenses')) {
          return StateMessage(
            icon: LucideIcons.sparkles,
            title: t('Im Paket nicht enthalten', 'Ni vključeno v paket'),
            body: t(
              'Ausgaben, Belegupload und Erkennung sind ab dem Paket Business verfügbar. Bestehende Daten bleiben erhalten.',
              'Stroški, nalaganje in prepoznava računov so na voljo od paketa Business naprej. Obstoječi podatki ostanejo.',
            ),
            actionLabel: t('Pakete ansehen', 'Poglej pakete'),
            onAction: () => context.push('/finance/plans'),
          );
        }
        final list = [...snap.state.expenses]..sort((a, b) => b.incurredOn.compareTo(a.incurredOn));
        final total = list.fold<int>(0, (a, e) => a + e.amountCents);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
          children: [
            PageHeader(
              kicker: 'Equitensa Finance / ${snap.state.country.code}',
              title: t('Ausgaben', 'Stroški'),
              subtitle: t(
                'Belege fotografieren, prüfen und erfassen – ohne automatische Buchung.',
                'Fotografirajte račune, preverite in evidentirajte – brez samodejnega knjiženja.',
              ),
            ),
            const SizedBox(height: 18),
            EqButton(
              label: t('Beleg scannen', 'Skeniraj račun'),
              icon: LucideIcons.scanLine,
              onPressed: () => context.push('/finance/receipt'),
            ),
            const SizedBox(height: 10),
            EqButton(
              kind: BtnKind.secondary,
              label: t('Ausgabe manuell erfassen', 'Ročni vnos stroška'),
              icon: LucideIcons.pencil,
              onPressed: () => context.push('/finance/receipt?manual=1'),
            ),
            const SizedBox(height: 18),
            EqCard(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Eq.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.wallet, color: Eq.warning),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Erfasste Ausgaben', 'Evidentirani stroški'),
                          style: TextStyle(color: context.eq.muted, fontSize: 13),
                        ),
                        Text(
                          fmt.money(total),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: context.eq.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${list.length}',
                    style: TextStyle(color: context.eq.faint, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              StateMessageInline(
                icon: LucideIcons.wallet,
                title: t('Noch keine Ausgaben', 'Še ni stroškov'),
                body: t(
                  'Fotografieren Sie einen Beleg – Sie prüfen die erkannten Daten vor dem Speichern.',
                  'Fotografirajte račun – pred shranjevanjem preverite prepoznane podatke.',
                ),
              )
            else
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EqCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.eq.violetSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            categoryIcon(e.category),
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
                                e.supplier,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: context.eq.ink2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${categoryLabel(t, e.category)} · ${e.incurredOn} · ${e.reference}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.eq.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          fmt.money(e.amountCents),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
