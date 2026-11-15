import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  AppModule get module =>
      location.startsWith('/pay') ? AppModule.pay : AppModule.finance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final company = ref.watch(sessionProvider);
    if (company == null) return const SizedBox.shrink();

    final tabs = module == AppModule.finance
        ? [
            _Tab(
              '/finance',
              Icons.space_dashboard_outlined,
              Icons.space_dashboard_rounded,
              'tab_overview',
            ),
            _Tab(
              '/finance/invoices',
              Icons.receipt_long_outlined,
              Icons.receipt_long_rounded,
              'tab_invoices',
            ),
            _Tab(
              '/finance/customers',
              Icons.groups_outlined,
              Icons.groups_rounded,
              'tab_customers',
            ),
            _Tab(
              '/finance/expenses',
              Icons.account_balance_wallet_outlined,
              Icons.account_balance_wallet_rounded,
              'tab_expenses',
            ),
          ]
        : [
            _Tab(
              '/pay',
              Icons.insights_outlined,
              Icons.insights_rounded,
              'tab_overview',
            ),
            _Tab(
              '/pay/reports',
              Icons.fact_check_outlined,
              Icons.fact_check_rounded,
              'tab_reports',
            ),
            _Tab(
              '/pay/categories',
              Icons.category_outlined,
              Icons.category_rounded,
              'tab_categories',
            ),
          ];
    final index = tabs
        .indexWhere((t) => t.path == location)
        .clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: Brand.violetDeep,
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: module == AppModule.pay
                  ? Brand.payGradient
                  : Brand.financeGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const BrandMark(size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                company.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${company.country.flag} ${company.country.code} · ${company.city}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          tooltip: s.t('account'),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          onPressed: () => context.push('/account'),
                          icon: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ModuleSwitch(company: company, active: module),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: ColoredBox(color: Brand.bg, child: child),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Brand.surface,
          indicatorColor: Brand.violet.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (st) => TextStyle(
              fontSize: 12,
              fontWeight: st.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: st.contains(WidgetState.selected)
                  ? Brand.violet
                  : Brand.muted,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(tabs[i].path),
          destinations: [
            for (final t in tabs)
              NavigationDestination(
                icon: Icon(t.icon, color: Brand.muted),
                selectedIcon: Icon(t.selectedIcon, color: Brand.violet),
                label: s.t(t.labelKey),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.icon, this.selectedIcon, this.labelKey);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
}

/// Same position in both workspaces. Locked modules explain why; switching never buys anything.
class _ModuleSwitch extends StatelessWidget {
  const _ModuleSwitch({required this.company, required this.active});
  final Company company;
  final AppModule active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final m in AppModule.values)
            Expanded(child: _segment(context, m)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, AppModule m) {
    final s = S.of(context);
    final selected = m == active;
    final available = company.hasModule(m);
    final label = m == AppModule.pay ? 'PAY' : 'FINANCE';
    return Semantics(
      button: true,
      selected: selected,
      label: available ? label : '$label ${s.t('module_locked')}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!available) {
            _showLocked(context, m);
          } else if (!selected) {
            context.go(m == AppModule.pay ? '/pay' : '/finance');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!available) ...[
                Icon(
                  Icons.lock_rounded,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Brand.violet
                      : Colors.white.withValues(alpha: available ? 1 : 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocked(BuildContext context, AppModule m) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 40,
              color: Brand.violet,
            ),
            const SizedBox(height: 12),
            Text(
              s.t(
                m == AppModule.pay
                    ? 'locked_pay_title'
                    : 'locked_finance_title',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              s.t('locked_body'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.t('close')),
            ),
          ],
        ),
      ),
    );
  }
}
