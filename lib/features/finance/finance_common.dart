import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';

/// Same merge order as the web composer: defaults < company design < document appearance.
DocDesign designFor(FinanceState s, FinDoc? d) => DocDesign.merge([
  s.profile.design,
  d?.appearance == null ? null : (d!.appearance!['design'] as Map?)?.cast<String, dynamic>(),
]);

String accentFor(FinanceState s, FinDoc? d) {
  final a = d?.appearance?['accent'];
  return a is String && a.isNotEmpty ? a : s.profile.accent;
}

({String label, Color color}) statusOf(Tr t, FinDoc d) {
  final today = Fmt.today();
  if (d.isDraft) return (label: t('Entwurf', 'Osnutek'), color: Eq.muted);
  if (d.isOffer) return (label: t('Angebot', 'Ponudba'), color: Eq.violet);
  if (d.isOverdue(today)) return (label: t('Überfällig', 'Zapadlo'), color: Eq.danger);
  if (d.isUnpaid) return (label: t('Offen', 'Odprto'), color: Eq.warning);
  return (label: t('Bezahlt', 'Plačano'), color: Eq.success);
}

/// Top bar for pushed screens: web look on the light page background.
class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottom,
    this.kicker,
  });
  final String title;
  final String? kicker;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.eq.page,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Row(
              children: [
                _RoundBtn(
                  icon: LucideIcons.arrowLeft,
                  onTap: () => context.canPop() ? context.pop() : context.go('/finance'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kicker != null) Kicker(kicker!),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: context.eq.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                ...?actions,
              ],
            ),
          ),
          Expanded(child: child),
          if (bottom != null)
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: context.eq.surface,
                border: Border(top: BorderSide(color: context.eq.line)),
              ),
              child: bottom,
            ),
        ],
      ),
    ),
  );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: context.eq.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.eq.line),
      ),
      child: Icon(icon, size: 18, color: context.eq.ink2),
    ),
  );
}

/// Conflict handling required by the contract: reload, explain, never overwrite silently.
Future<void> showConflict(BuildContext context, WidgetRef ref) async {
  final t = trOf(ref);
  await ref.read(financeProvider.notifier).reload();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(LucideIcons.refreshCw, color: Eq.warning, size: 30),
      title: Text(
        t('Daten wurden geändert', 'Podatki so bili spremenjeni'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
      ),
      content: Text(
        t(
          'Jemand hat diese Daten im Web oder in der App geändert. Ihre Eingaben bleiben erhalten; prüfen Sie den aktuellen Stand und speichern Sie erneut.',
          'Nekdo je te podatke spremenil na spletu ali v aplikaciji. Vaši vnosi ostanejo; preverite trenutno stanje in shranite znova.',
        ),
        textAlign: TextAlign.center,
        style: TextStyle(color: context.eq.muted, height: 1.5),
      ),
      actions: [
        EqButton(
          label: t('Verstanden', 'Razumem'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    ),
  );
}

/// Runs a mutation and maps failures to the contract's UX states. Returns null when it failed.
Future<T?> guarded<T>(
  BuildContext context,
  WidgetRef ref,
  Future<T> Function() run,
) async {
  try {
    return await run();
  } on ApiException catch (e) {
    if (!context.mounted) return null;
    if (e.isConflict) {
      await showConflict(context, ref);
    } else {
      showApiError(context, e);
    }
    return null;
  }
}

String issueProblemLabel(Tr t, String code) => switch (code) {
  'country' => t(
    'Land der Firma bestätigen (Firma & Design)',
    'Potrdite državo podjetja (Podjetje in izgled)',
  ),
  'issuer.name' => t('Firmenname fehlt', 'Manjka ime podjetja'),
  'issuer.address' => t('Firmenadresse fehlt', 'Manjka naslov podjetja'),
  'issuer.postalCode' => t(
    'Firmen-PLZ fehlt',
    'Manjka poštna številka podjetja',
  ),
  'issuer.city' => t('Firmenort fehlt', 'Manjka kraj podjetja'),
  'issuer.iban' => t('IBAN fehlt', 'Manjka IBAN'),
  'issuer.vatId' => t('USt-IdNr. fehlt', 'Manjka davčna številka za DDV'),
  'issuer.vatId_format' => t(
    'USt-IdNr. hat ein ungültiges Format',
    'Davčna številka ima neveljavno obliko',
  ),
  'customer.name' => t('Kundenname fehlt', 'Manjka ime stranke'),
  'customer.address' => t('Kundenadresse fehlt', 'Manjka naslov stranke'),
  'customer.postalCode' => t(
    'Kunden-PLZ fehlt',
    'Manjka poštna številka stranke',
  ),
  'customer.city' => t('Kundenort fehlt', 'Manjka kraj stranke'),
  'customer.vatId' => t(
    'USt-IdNr. des Kunden fehlt',
    'Manjka davčna številka stranke',
  ),
  'customer.vatId_format' => t(
    'USt-IdNr. des Kunden ungültig',
    'Davčna številka stranke je neveljavna',
  ),
  'cross_border_not_supported' => t(
    'Grenzüberschreitend wird nicht unterstützt',
    'Čezmejno ni podprto',
  ),
  'private_domestic_b2b_only' => t(
    'Nur inländische B2B-Kunden (privat)',
    'Samo domače zasebne B2B stranke',
  ),
  'future_issue_date' => t(
    'Rechnungsdatum liegt in der Zukunft',
    'Datum računa je v prihodnosti',
  ),
  'already_issued' => t('Bereits ausgestellt', 'Že izdano'),
  'structured_einvoice_not_yet_validated' => t(
    'Strukturierte E-Rechnung noch nicht validiert',
    'Strukturirani e-račun še ni validiran',
  ),
  'validator_unavailable' => t(
    'Validator nicht verfügbar',
    'Validator ni na voljo',
  ),
  _ => code,
};

/// Shows finance data states (loading, errors) for every Finance screen.
class FinanceView extends ConsumerWidget {
  const FinanceView({super.key, required this.builder, this.loading});
  final Widget Function(BuildContext, FinanceSnapshot) builder;
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView<FinanceSnapshot>(
    value: ref.watch(financeProvider),
    onRefresh: () => ref.read(financeProvider.notifier).reload(),
    loading: loading,
    builder: builder,
  );
}

String kindLabel(Tr t, String kind) => kind == 'offer' ? t('Angebot', 'Ponudba') : t('Rechnung', 'Račun');
