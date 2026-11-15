import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/account/account_screen.dart';
import 'features/auth/auth_pages.dart';
import 'features/auth/auth_widgets.dart';
import 'features/auth/register_page.dart';
import 'features/auth/splash_page.dart';
import 'features/finance/company_screen.dart';
import 'features/finance/composer_screen.dart';
import 'features/finance/contacts_screen.dart';
import 'features/finance/document_detail.dart';
import 'features/finance/expenses_screen.dart';
import 'features/finance/finance_overview.dart';
import 'features/finance/plans_screen.dart';
import 'features/finance/receipt_screen.dart';
import 'features/finance/sales_screen.dart';
import 'features/pay/pay_screens.dart';
import 'features/shell/shell.dart';

final launchReadyProvider = FutureProvider<void>((ref) => Future<void>.delayed(const Duration(milliseconds: 950)));

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.listen(launchReadyProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  Page<void> fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
    key: s.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (_, anim, _, c) => FadeTransition(opacity: anim, child: c),
  );

  Page<void> slide(GoRouterState s, Widget child) => defaultTargetPlatform == TargetPlatform.iOS
      ? CupertinoPage<void>(key: s.pageKey, child: child)
      : CustomTransitionPage<void>(
          key: s.pageKey,
          child: child,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (_, anim, _, c) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: c,
            ),
          ),
        );

  const authPaths = {'/welcome', '/login', '/register', '/forgot', '/reset'};

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (ref.read(launchReadyProvider).isLoading) return loc == '/splash' ? null : '/splash';
      if (session.isLoading && !session.hasValue) return loc == '/splash' ? null : '/splash';
      final me = session.value;
      if (me == null) return authPaths.contains(loc) ? null : '/welcome';
      if (!me.emailVerified) return loc == '/verify' ? null : '/verify';
      if (loc == '/splash' || loc == '/verify' || authPaths.contains(loc)) return '/finance';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      ShellRoute(
        builder: (_, _, child) => AuthFrame(child: child),
        routes: [
          GoRoute(
            path: '/welcome',
            pageBuilder: (_, s) => fade(s, const WelcomePage()),
          ),
          GoRoute(
            path: '/login',
            pageBuilder: (_, s) => slide(s, const LoginPage()),
          ),
          GoRoute(
            path: '/register',
            pageBuilder: (_, s) => slide(s, const RegisterPage()),
          ),
          GoRoute(
            path: '/forgot',
            pageBuilder: (_, s) => slide(s, const ForgotPage()),
          ),
          GoRoute(
            path: '/reset',
            pageBuilder: (_, s) => slide(s, const ResetPage()),
          ),
          GoRoute(
            path: '/verify',
            pageBuilder: (_, s) => fade(s, const VerifyPage()),
          ),
        ],
      ),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/finance',
            pageBuilder: (_, s) => fade(s, const FinanceOverviewScreen()),
          ),
          GoRoute(
            path: '/finance/sales',
            pageBuilder: (_, s) => fade(s, const SalesScreen()),
          ),
          GoRoute(
            path: '/finance/contacts',
            pageBuilder: (_, s) => fade(s, const ContactsScreen()),
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
            path: '/pay/report',
            pageBuilder: (_, s) => fade(s, const PayReportScreen()),
          ),
          GoRoute(
            path: '/pay/categories',
            pageBuilder: (_, s) => fade(s, const PayCategoriesScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/finance/compose',
        pageBuilder: (_, s) => slide(
          s,
          ComposerScreen(
            kind: s.uri.queryParameters['kind'] ?? 'invoice',
            editId: s.uri.queryParameters['edit'],
          ),
        ),
      ),
      GoRoute(
        path: '/finance/document/:id',
        pageBuilder: (_, s) => slide(s, DocumentDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/finance/contact',
        pageBuilder: (_, s) => slide(s, ContactFormScreen(editId: s.uri.queryParameters['edit'])),
      ),
      GoRoute(
        path: '/finance/receipt',
        pageBuilder: (_, s) => slide(
          s,
          ReceiptScreen(manual: s.uri.queryParameters['manual'] == '1'),
        ),
      ),
      GoRoute(
        path: '/finance/plans',
        pageBuilder: (_, s) => slide(s, const PlansScreen()),
      ),
      GoRoute(
        path: '/finance/company',
        pageBuilder: (_, s) => slide(s, const CompanyScreen()),
      ),
      GoRoute(
        path: '/account',
        pageBuilder: (_, s) => slide(s, const AccountScreen()),
      ),
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
      supportedLocales: const [Locale('de'), Locale('sl')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // fl_chart still reads the bundled design libraries. Keep their theme in
      // sync until that dependency completes the Flutter 3.50 migration.
      // ignore: deprecated_member_use
      builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
