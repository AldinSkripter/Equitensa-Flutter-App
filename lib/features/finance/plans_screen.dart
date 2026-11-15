import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../domain/models.dart';
import 'finance_common.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String? _plan;
  int _seats = 1;
  String _interval = 'monthly';
  Map<String, dynamic>? _quote;
  Object? _quoteError;
  bool _loadingQuote = false;
  bool _saving = false;

  String _displayName(Tr t, Country country, PlanInfo p) =>
      p.id == 'finance_start' ? (country == Country.si ? 'Računi' : 'Rechnungen') : p.name;

  Future<void> _fetch() async {
    if (_plan == null) return;
    setState(() {
      _loadingQuote = true;
      _quoteError = null;
    });
    try {
      final q = await ref.read(repositoryProvider).quote(_plan!, _seats, _interval);
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) setState(() => _quoteError = e);
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  void _select(PlanInfo p) {
    setState(() {
      _plan = p.id;
      _seats = p.includedSeats;
    });
    _fetch();
  }

  Future<void> _activate(FinanceSnapshot snap) async {
    final t = trOf(ref);
    setState(() => _saving = true);
    final res = await guarded(
      context,
      ref,
      () => ref
          .read(financeProvider.notifier)
          .mutate(
            (rev) => ref.read(repositoryProvider).demoSubscription(_plan!, _seats, _interval),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      showSnack(
        context,
        t(
          'Demo-Paket gespeichert (kein echter Kauf).',
          'Demo paket shranjen (ni pravi nakup).',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    final country = ref.watch(countryProvider);
    return SubPage(
      kicker: 'Equitensa Finance',
      title: t('Paket & Team', 'Paket in ekipa'),
      child: FinanceView(
        builder: (context, snap) {
          final current = snap.state.planId;
          PlanInfo? selected = snap.plans.where((p) => p.id == _plan).firstOrNull;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              NoticeBanner(
                t(
                  'Preise zur Information. Der Wechsel hier ist eine Demo-Simulation – kein Kauf, keine Zahlung. Ein Tab-Wechsel kauft nie ein Modul.',
                  'Cene so informativne. Zamenjava tukaj je demo simulacija – ni nakupa ali plačila. Preklop zavihka nikoli ne kupi modula.',
                ),
              ),
              const SizedBox(height: 14),
              EqCard(
                child: Row(
                  children: [
                    const Icon(LucideIcons.badgeCheck, color: Eq.violet),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Aktueller Stand', 'Trenutno stanje'),
                            style: TextStyle(
                              color: context.eq.muted,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            current == null
                                ? t(
                                    'Kein Paket gewählt – volle Erkundung (Demo)',
                                    'Paket ni izbran – polno raziskovanje (demo)',
                                  )
                                : _displayName(
                                    t,
                                    country,
                                    snap.plans.firstWhere(
                                      (p) => p.id == current,
                                      orElse: () => PlanInfo(current, current, 0, 0),
                                    ),
                                  ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.eq.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final p in snap.plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanCard(
                    name: _displayName(t, country, p),
                    price: fmt.money(p.monthlyCents),
                    seats:
                        '${p.includedSeats} ${p.includedSeats == 1 ? t('Platz', 'uporabnik') : t('Plätze', 'uporabniki')}',
                    active: p.id == current,
                    selected: p.id == _plan,
                    features: [
                      (
                        t(
                          'Kunden, Angebote und Rechnungen',
                          'Stranke, ponudbe in računi',
                        ),
                        true,
                      ),
                      (
                        t(
                          'PDF und E-Rechnung (Testexport)',
                          'PDF in e-račun (testni izvoz)',
                        ),
                        true,
                      ),
                      (
                        t(
                          'Ausgaben und Belegupload',
                          'Stroški in nalaganje računov',
                        ),
                        p.level >= 1,
                      ),
                      (
                        t(
                          'Belegerkennung per Kamera',
                          'Prepoznava računov s kamero',
                        ),
                        p.level >= 1,
                      ),
                      (
                        t(
                          'Bank-CSV und Zuordnung',
                          'Bančni CSV in usklajevanje',
                        ),
                        p.level >= 1,
                      ),
                      (
                        t('Wiederkehrende Entwürfe', 'Ponavljajoči osnutki'),
                        p.level >= 2,
                      ),
                    ],
                    perMonth: t('/ Monat netto', '/ mesec neto'),
                    term: t(
                      '12 Monate Mindestlaufzeit',
                      '12 mesecev minimalna doba',
                    ),
                    currentLabel: t('Aktuell', 'Trenutno'),
                    onTap: () => _select(p),
                  ),
                ),
              if (selected != null) ...[
                const SizedBox(height: 4),
                EqCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(t, country, selected),
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: context.eq.ink2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.eq.violetSoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            for (final (k, label) in [
                              ('monthly', t('Monatlich', 'Mesečno')),
                              ('annual', t('Jährlich', 'Letno')),
                            ])
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _interval = k);
                                    _fetch();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _interval == k ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _interval == k ? Eq.cardShadow : null,
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _interval == k ? Eq.violet : context.eq.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (selected.id != 'finance_start') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t('Interne Plätze', 'Interni uporabniki'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              onPressed: _seats > selected.includedSeats
                                  ? () {
                                      setState(() => _seats--);
                                      _fetch();
                                    }
                                  : null,
                              icon: const Icon(LucideIcons.minus, size: 16),
                            ),
                            SizedBox(
                              width: 38,
                              child: Center(
                                child: Text(
                                  '$_seats',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              onPressed: _seats < 50
                                  ? () {
                                      setState(() => _seats++);
                                      _fetch();
                                    }
                                  : null,
                              icon: const Icon(LucideIcons.plus, size: 16),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 12),
                      if (_loadingQuote)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      else if (_quoteError != null)
                        NoticeBanner(
                          errorMessage(t, _quoteError!),
                          color: Eq.danger,
                        )
                      else if (_quote != null) ...[
                        _qRow(
                          t('Grundpreis / Monat', 'Osnovna cena / mesec'),
                          fmt.money(
                            (_quote!['baseMonthlyCents'] as num).toInt(),
                          ),
                        ),
                        if (((_quote!['extraSeats'] as num?) ?? 0) > 0)
                          _qRow(
                            '${_quote!['extraSeats']} ${t('zusätzliche Plätze', 'dodatni uporabniki')}',
                            fmt.money(
                              (_quote!['extraMonthlyCents'] as num).toInt(),
                            ),
                          ),
                        _qRow(
                          t('Monatlich netto', 'Mesečno neto'),
                          fmt.money((_quote!['monthlyCents'] as num).toInt()),
                        ),
                        const SizedBox(height: 6),
                        _qRow(
                          _interval == 'annual'
                              ? t('Jahreszahlung netto', 'Letno plačilo neto')
                              : t(
                                  'Fällig pro Monat netto',
                                  'Plačilo na mesec neto',
                                ),
                          fmt.money((_quote!['chargeCents'] as num).toInt()),
                          big: true,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(
                                'Mindestlaufzeit 12 Monate · Mindestsumme ',
                                'Minimalna doba 12 mesecev · Minimalni znesek ',
                              ) +
                              fmt.money(
                                (_quote!['minimumTotalCents'] as num).toInt(),
                              ),
                          style: TextStyle(
                            color: context.eq.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (snap.demo)
                        EqButton(
                          label: t(
                            'Demo: Paket simulieren',
                            'Demo: simuliraj paket',
                          ),
                          icon: LucideIcons.flaskConical,
                          busy: _saving,
                          onPressed: _quote == null ? null : () => _activate(snap),
                        )
                      else
                        Text(
                          t(
                            'Echte Buchung ist noch nicht freigegeben.',
                            'Pravo naročanje še ni sproščeno.',
                          ),
                          style: TextStyle(color: context.eq.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _qRow(String l, String v, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            l,
            style: TextStyle(
              fontWeight: big ? FontWeight.w700 : FontWeight.w500,
              color: context.eq.ink2,
            ),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: big ? 21 : 14.5,
            color: big ? Eq.violet : context.eq.ink2,
            letterSpacing: big ? -0.5 : 0,
          ),
        ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.seats,
    required this.active,
    required this.selected,
    required this.features,
    required this.perMonth,
    required this.term,
    required this.currentLabel,
    required this.onTap,
  });

  final String name, price, seats, perMonth, term, currentLabel;
  final bool active, selected;
  final List<(String, bool)> features;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.eq.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Eq.violet : context.eq.line,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected ? Eq.glow : Eq.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: context.eq.ink2,
                ),
              ),
              const Spacer(),
              if (active) Pill(currentLabel, color: Eq.success, icon: LucideIcons.check),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: Eq.violet,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  perMonth,
                  style: TextStyle(color: context.eq.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
          Text(
            '$seats · $term',
            style: TextStyle(color: context.eq.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    f.$2 ? LucideIcons.circleCheck : LucideIcons.circleMinus,
                    size: 17,
                    color: f.$2 ? Eq.success : context.eq.line,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.$1,
                      style: TextStyle(
                        color: f.$2 ? context.eq.ink : context.eq.faint,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
