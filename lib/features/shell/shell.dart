import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/appearance.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../domain/models.dart';

enum Workspace { pay, finance }

class _Tab {
  const _Tab(this.path, this.icon, this.de, this.sl);
  final String path;
  final IconData icon;
  final String de;
  final String sl;
}

const _financeTabs = [
  _Tab('/finance', LucideIcons.layoutDashboard, 'Übersicht', 'Pregled'),
  _Tab('/finance/sales', LucideIcons.fileText, 'Verkauf', 'Prodaja'),
  _Tab('/finance/contacts', LucideIcons.users, 'Kontakte', 'Stiki'),
  _Tab('/finance/expenses', LucideIcons.wallet, 'Ausgaben', 'Stroški'),
];

const _payTabs = [
  _Tab('/pay', LucideIcons.chartNoAxesCombined, 'Übersicht', 'Pregled'),
  _Tab('/pay/report', LucideIcons.fileCheck, 'Bericht', 'Poročilo'),
  _Tab('/pay/categories', LucideIcons.layers, 'Kategorien', 'Kategorije'),
];

Workspace workspaceOf(String location) => location.startsWith('/pay') ? Workspace.pay : Workspace.finance;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final me = ref.watch(sessionProvider).value;
    if (me == null) return const SizedBox.shrink();
    final ws = workspaceOf(location);
    final tabs = ws == Workspace.finance ? _financeTabs : _payTabs;
    final index = tabs.indexWhere((x) => x.path == location).clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: Eq.plum,
      drawer: EqDrawer(workspace: ws),
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              _Stage(me: me, workspace: ws),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: ColoredBox(
                    color: context.eq.page,
                    child: RefreshIndicator(
                      onRefresh: () async {
                        try {
                          await refreshWorkspace(ref);
                        } catch (error) {
                          if (context.mounted) showApiError(context, error);
                        }
                      },
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _Dock(
                  tabs: tabs,
                  index: index,
                  showCreate: ws == Workspace.finance,
                  t: t,
                  onTab: (i) => context.go(tabs[i].path),
                  onCreate: () => showCreateSheet(context, ref),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stage extends ConsumerWidget {
  const _Stage({required this.me, required this.workspace});
  final Me me;
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = me.company;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: workspace == Workspace.pay ? const Alignment(-0.9, -1.2) : const Alignment(0.9, -1.2),
          radius: 1.5,
          colors: const [Color(0xFF3B2764), Eq.plum],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Builder(
                    builder: (ctx) => _GlassIcon(
                      icon: LucideIcons.menu,
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16.5,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '${c.country.flag} ${c.country.code} · EUR',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Theme(
                    data: buildTheme(brightness: Brightness.dark),
                    child: const AppearanceButton(),
                  ),
                  _GlassIcon(
                    icon: LucideIcons.circleUser,
                    onTap: () => context.push('/account'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ModuleSwitch(workspace: workspace),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(icon, size: 19, color: Colors.white),
    ),
  );
}

/// Same place in both workspaces. A sliding thumb shows where you are.
class _ModuleSwitch extends ConsumerWidget {
  const _ModuleSwitch({required this.workspace});
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final pay = workspace == Workspace.pay;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                left: pay ? 0 : w,
                width: w,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: Eq.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Eq.violet.withValues(alpha: 0.55),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _seg(
                    context,
                    'PAY',
                    t('Entgelttransparenz', 'Transparentnost plač'),
                    LucideIcons.chartNoAxesCombined,
                    pay,
                    '/pay',
                  ),
                  _seg(
                    context,
                    'FINANCE',
                    t('Rechnungen & Belege', 'Računi in dokumenti'),
                    LucideIcons.receiptText,
                    !pay,
                    '/finance',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _seg(
    BuildContext context,
    String label,
    String sub,
    IconData icon,
    bool selected,
    String path,
  ) => Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!selected) {
          HapticFeedback.selectionClick();
          context.go(path);
        }
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: selected ? 1 : 0.6),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: selected ? 1 : 0.65),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Dock extends StatelessWidget {
  const _Dock({
    required this.tabs,
    required this.index,
    required this.showCreate,
    required this.t,
    required this.onTab,
    required this.onCreate,
  });

  final List<_Tab> tabs;
  final int index;
  final bool showCreate;
  final Tr t;
  final ValueChanged<int> onTab;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: context.eq.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: context.eq.line),
      boxShadow: [BoxShadow(color: context.eq.ink.withValues(alpha: .10), blurRadius: 32, offset: const Offset(0, 8))],
    ),
    child: Row(
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (showCreate && i == tabs.length ~/ 2) _createButton(context),
          Expanded(
            child: Semantics(
              selected: i == index,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTab(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: i == index ? context.eq.violetSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tabs[i].icon, size: 21, color: i == index ? context.eq.accent : context.eq.faint),
                        const SizedBox(height: 5),
                        Text(
                          t(tabs[i].de, tabs[i].sl),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: i == index ? context.eq.accent : context.eq.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _createButton(BuildContext context) => Expanded(
    child: Center(
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton.filled(
          tooltip: t('Neu erstellen', 'Ustvari novo'),
          style: IconButton.styleFrom(
            backgroundColor: Eq.violet,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onCreate,
          icon: const Icon(LucideIcons.plus, size: 22),
        ),
      ),
    ),
  );
}

/// "+" menu in the dock: create a document, contact or receipt.
Future<void> showCreateSheet(BuildContext context, WidgetRef ref) {
  final t = trOf(ref);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.eq.surface,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(t('Neu erstellen', 'Ustvari novo')),
            const SizedBox(height: 14),
            for (final item in [
              (
                LucideIcons.fileText,
                t('Rechnung', 'Račun'),
                t('Entwurf mit Live-Dokument', 'Osnutek z dokumentom v živo'),
                '/finance/compose?kind=invoice',
              ),
              (
                LucideIcons.fileCheck,
                t('Angebot', 'Ponudba'),
                t('Später in Rechnung umwandeln', 'Pozneje pretvorite v račun'),
                '/finance/compose?kind=offer',
              ),
              (
                LucideIcons.userPlus,
                t('Kontakt', 'Stik'),
                t('Kunde oder Lieferant', 'Stranka ali dobavitelj'),
                '/finance/contact',
              ),
              (
                LucideIcons.scanLine,
                t('Beleg scannen', 'Skeniraj račun'),
                t(
                  'Kamera, prüfen, erfassen',
                  'Kamera, preverite, evidentirajte',
                ),
                '/finance/receipt',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: EqCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push(item.$4);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.eq.violetSoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(item.$1, size: 20, color: Eq.violet),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                                color: context.eq.ink2,
                              ),
                            ),
                            Text(
                              item.$3,
                              style: TextStyle(
                                color: context.eq.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: context.eq.faint,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Web sidebar, adapted: logo, company, module switcher, workspace navigation, account.
class EqDrawer extends ConsumerWidget {
  const EqDrawer({super.key, required this.workspace});
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final me = ref.watch(sessionProvider).value;
    if (me == null) return const SizedBox.shrink();
    final location = GoRouterState.of(context).matchedLocation;
    final pay = workspace == Workspace.pay;

    final items = pay
        ? [
            (
              LucideIcons.chartNoAxesCombined,
              t('Übersicht', 'Pregled'),
              '/pay',
            ),
            (
              LucideIcons.fileCheck,
              t('Bericht vorbereiten', 'Priprava poročila'),
              '/pay/report',
            ),
            (
              LucideIcons.layers,
              t('Kategorien', 'Kategorije'),
              '/pay/categories',
            ),
          ]
        : [
            (
              LucideIcons.layoutDashboard,
              t('Übersicht', 'Pregled'),
              '/finance',
            ),
            (
              LucideIcons.receiptText,
              t('Verkauf', 'Prodaja'),
              '/finance/sales',
            ),
            (LucideIcons.users, t('Kontakte', 'Stiki'), '/finance/contacts'),
            (LucideIcons.wallet, t('Ausgaben', 'Stroški'), '/finance/expenses'),
            (
              LucideIcons.package,
              t('Paket & Team', 'Paket in ekipa'),
              '/finance/plans',
            ),
            (
              LucideIcons.settings,
              t('Firma & Design', 'Podjetje in izgled'),
              '/finance/company',
            ),
          ];

    return Drawer(
      width: 308,
      backgroundColor: Eq.plum,
      shape: const RoundedRectangleBorder(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-1, -1),
            radius: 1.3,
            colors: [Eq.plum2, Eq.plum],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            children: [
              const Wordmark(size: 25),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Pill(
                  pay ? 'PAY' : 'FINANCE',
                  color: const Color(0xFFB9A2FF),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Eq.plumLine),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.building2,
                      size: 20,
                      color: Eq.onPlumMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            me.company.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${me.company.country.code} · EUR',
                            style: const TextStyle(
                              color: Eq.onPlumMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Eq.plumLine),
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(6, 4, 6, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Kicker('Equitensa Suite', color: Eq.onPlumMuted),
                      ),
                    ),
                    _suite(
                      context,
                      'Pay',
                      t('Entgelttransparenz', 'Transparentnost plač'),
                      LucideIcons.chartNoAxesCombined,
                      pay,
                      '/pay',
                    ),
                    const SizedBox(height: 6),
                    _suite(
                      context,
                      'Finance',
                      t('Rechnungen & Belege', 'Računi in dokumenti'),
                      LucideIcons.receiptText,
                      !pay,
                      '/finance',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 8),
                child: Kicker('Workspace', color: Eq.onPlumMuted),
              ),
              for (final it in items) _nav(context, it.$1, it.$2, it.$3, location == it.$3),
              const SizedBox(height: 18),
              const Divider(color: Eq.plumLine),
              const SizedBox(height: 8),
              _nav(
                context,
                LucideIcons.circleUser,
                t('Konto & Sicherheit', 'Račun in varnost'),
                '/account',
                false,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(
                  LucideIcons.logOut,
                  size: 19,
                  color: Eq.onPlumMuted,
                ),
                title: Text(
                  t('Abmelden', 'Odjava'),
                  style: const TextStyle(
                    color: Eq.onPlumMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(sessionProvider.notifier).logout();
                },
              ),
              const SizedBox(height: 14),
              Text(
                t(
                  'Eigener Arbeitsbereich. Pay-Abonnement und HR-Daten bleiben getrennt.',
                  'Lasten delovni prostor. Naročnina Pay in kadrovski podatki ostanejo ločeni.',
                ),
                style: const TextStyle(
                  color: Eq.onPlumMuted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suite(
    BuildContext context,
    String name,
    String sub,
    IconData icon,
    bool on,
    String path,
  ) => Material(
    color: on ? Eq.violet : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pop();
        context.go(path);
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (on)
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8CCFF),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _nav(
    BuildContext context,
    IconData icon,
    String label,
    String path,
    bool on,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: on ? Eq.violet : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop();
          if (path == '/account' || path == '/finance/plans' || path == '/finance/company') {
            context.push(path);
          } else {
            context.go(path);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: on ? Colors.white : Eq.onPlumMuted),
              const SizedBox(width: 13),
              Text(
                label,
                style: TextStyle(
                  color: on ? Colors.white : Eq.onPlumMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
