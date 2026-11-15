import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _busy;

  Future<void> _enter(String id) async {
    setState(() => _busy = id);
    try {
      await ref.read(sessionProvider.notifier).signIn(id);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final companies = ref.watch(companiesProvider);

    return Scaffold(
      backgroundColor: Brand.violetDeep,
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.financeGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 320,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.6, end: 1),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.elasticOut,
                            builder: (_, v, child) =>
                                Transform.scale(scale: v, child: child),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 40,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: const BrandMark(size: 92),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Equitensa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.t('tagline'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 8,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Brand.bg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    children: [
                      Text(
                        s.t('choose_company'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.t('choose_company_hint'),
                        style: const TextStyle(color: Brand.muted),
                      ),
                      const SizedBox(height: 18),
                      companies.when(
                        loading: () => const Column(
                          children: [
                            Skeleton(height: 76),
                            SizedBox(height: 12),
                            Skeleton(height: 76),
                            SizedBox(height: 12),
                            Skeleton(height: 76),
                          ],
                        ),
                        error: (e, _) => SizedBox(
                          height: 280,
                          child: ErrorView(
                            error: e,
                            onRetry: () => ref.invalidate(companiesProvider),
                          ),
                        ),
                        data: (list) => Column(
                          children: [
                            for (final c in list)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  onTap: _busy == null
                                      ? () => _enter(c.id)
                                      : null,
                                  child: Row(
                                    children: [
                                      Text(
                                        c.country.flag,
                                        style: const TextStyle(fontSize: 32),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${c.country.label} · ${c.city}',
                                              style: const TextStyle(
                                                color: Brand.muted,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                if (c.payActive)
                                                  Pill(
                                                    'PAY',
                                                    color: Brand.violet,
                                                  ),
                                                if (c.financeActive)
                                                  Pill(
                                                    'FINANCE',
                                                    color: Brand.violetDeep,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      _busy == c.id
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 16,
                                              color: Brand.muted,
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Brand.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Brand.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.t('demo_notice'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Brand.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
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
}
