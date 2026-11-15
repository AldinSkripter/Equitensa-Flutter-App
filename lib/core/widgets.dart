import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import 'l10n.dart';
import 'theme.dart';

String fmtMoney(int cents, String lang) => NumberFormat.currency(
  locale: lang,
  symbol: '€',
  decimalDigits: 2,
).format(cents / 100);

String fmtMoneyShort(int cents, String lang) => NumberFormat.compactCurrency(
  locale: lang,
  symbol: '€',
  decimalDigits: 0,
).format(cents / 100);

String fmtDate(DateTime d, String lang) => DateFormat.yMMMd(lang).format(d);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.28),
    child: Image.asset('assets/brand/equitensa.png', width: size, height: size),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Brand.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Brand.border),
      boxShadow: Brand.softShadow,
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon case final i?) ...[
          Icon(i, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (color, key) = switch (status) {
      InvoiceStatus.draft => (Brand.muted, 'st_draft'),
      InvoiceStatus.issued => (Brand.violet, 'st_issued'),
      InvoiceStatus.paid => (Brand.success, 'st_paid'),
      InvoiceStatus.overdue => (Brand.danger, 'st_overdue'),
    };
    return Pill(s.t(key), color: color);
  }
}

/// Full-area message used for empty, offline, denied, upgrade and error states.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.color = Brand.violet,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Brand.muted,
              height: 1.4,
              fontSize: 15,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

/// Maps repository failures onto the mandatory UI states.
class ErrorView extends ConsumerWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return switch (error) {
      OfflineException() => StateMessage(
        icon: Icons.wifi_off_rounded,
        title: s.t('offline_title'),
        body: s.t('offline_body'),
        actionLabel: s.t('retry'),
        onAction: onRetry,
        color: Brand.warning,
      ),
      DeniedException() => StateMessage(
        icon: Icons.lock_outline_rounded,
        title: s.t('denied_title'),
        body: s.t('denied_body'),
        color: Brand.danger,
      ),
      PlanUpgradeException() => StateMessage(
        icon: Icons.workspace_premium_rounded,
        title: s.t('upgrade_title'),
        body: s.t('upgrade_body'),
        actionLabel: s.t('see_packages'),
        onAction: () => context.push('/packages'),
      ),
      _ => StateMessage(
        icon: Icons.error_outline_rounded,
        title: s.t('error_title'),
        body: s.t('error_body'),
        actionLabel: s.t('retry'),
        onAction: onRetry,
        color: Brand.danger,
      ),
    };
  }
}

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 80, this.radius = 20});
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFFEDE8F6),
          const Color(0xFFF8F5FD),
          _c.value,
        ),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 4, this.itemHeight = 84});
  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, _) => Skeleton(height: itemHeight),
  );
}

/// Standard data-screen wrapper: loading skeleton, errors, empty state, pull-to-refresh.
class AsyncBody<T> extends ConsumerWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
    this.isEmpty,
    this.empty,
    this.loading,
  });

  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, T) builder;
  final bool Function(T)? isEmpty;
  final Widget? empty;
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep showing previous data during a refresh instead of flashing a spinner.
    if (value.isLoading && !value.hasValue) {
      return loading ?? const LoadingList();
    }
    if (value.hasError && !value.hasValue) {
      return ErrorView(error: value.error!, onRetry: () => onRefresh());
    }
    final data = value.requireValue;
    if (isEmpty != null && isEmpty!(data) && empty != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (_, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: c.maxHeight, child: empty),
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: Brand.violet,
      onRefresh: onRefresh,
      child: builder(context, data),
    );
  }
}

void showError(BuildContext context, Object e) {
  final s = S.of(context);
  final key = switch (e) {
    OfflineException() => 'offline_title',
    DeniedException() => 'denied_title',
    PlanUpgradeException() => 'upgrade_title',
    ValidationException(:final messageKey) => messageKey,
    _ => 'error_title',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s.t(key))));
}
