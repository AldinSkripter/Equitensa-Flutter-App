import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/account/account_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/finance/customers.dart';
import 'features/finance/expenses.dart';
import 'features/finance/finance_overview.dart';
import 'features/finance/invoice_detail.dart';
import 'features/finance/invoice_editor.dart';
import 'features/finance/invoices.dart';
import 'features/finance/packages.dart';
import 'features/finance/receipt_screen.dart';
import 'features/pay/pay_screens.dart';
import 'features/shell/shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  Page<void> fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
    key: s.pageKey,
    child: child,
    transitionsBuilder: (_, anim, _, c) =>
        FadeTransition(opacity: anim, child: c),
  );

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final company = ref.read(sessionProvider);
      final atLogin = state.matchedLocation == '/login';
      if (company == null) return atLogin ? null : '/login';
      if (atLogin) return company.financeActive ? '/finance' : '/pay';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/finance',
            pageBuilder: (_, s) => fade(s, const FinanceOverviewScreen()),
          ),
          GoRoute(
            path: '/finance/invoices',
            pageBuilder: (_, s) => fade(s, const InvoicesScreen()),
          ),
          GoRoute(
            path: '/finance/customers',
            pageBuilder: (_, s) => fade(s, const CustomersScreen()),
          ),
          GoRoute(
            path: '/finance/expenses',
            pageBuilder: (_, s) => fade(s, const ExpensesScreen()),
          ),
          GoRoute(
            path: '/pay',
            pageBuilder: (_, s) => fade(s, const PayOverviewScreen()),
          ),
          GoRoute(
            path: '/pay/reports',
            pageBuilder: (_, s) => fade(s, const PayReportScreen()),
          ),
          GoRoute(
            path: '/pay/categories',
            pageBuilder: (_, s) => fade(s, const PayCategoriesScreen()),
          ),
        ],
      ),
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(path: '/packages', builder: (_, _) => const PackagesScreen()),
      GoRoute(
        path: '/invoice/new',
        builder: (_, _) => const InvoiceEditorScreen(),
      ),
      GoRoute(
        path: '/invoice/:id',
        builder: (_, s) => InvoiceDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customer/new',
        builder: (_, _) => const CustomerFormScreen(),
      ),
      GoRoute(path: '/receipt', builder: (_, _) => const ReceiptScreen()),
    ],
  );
});

class EquitensaApp extends ConsumerWidget {
  const EquitensaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return MaterialApp.router(
      title: 'Equitensa',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: S.supported,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
