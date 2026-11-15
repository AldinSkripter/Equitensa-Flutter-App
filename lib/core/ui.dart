import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api_client.dart';
import 'i18n.dart';
import 'providers.dart';
import 'theme.dart';

// ---------------------------------------------------------------- typography

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color = Eq.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
      color: color == context.eq.muted ? context.eq.muted : color,
    ),
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String kicker;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Kicker(kicker),
      const SizedBox(height: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 30,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          color: context.eq.ink2,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(
          subtitle!,
          style: TextStyle(fontSize: 14.5, height: 1.45, color: context.eq.muted),
        ),
      ],
      if (action != null) ...[const SizedBox(height: 18), action!],
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: context.eq.ink2,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

// --------------------------------------------------------------------- cards

class EqCard extends StatelessWidget {
  const EqCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        color: color ?? context.eq.surface,
        borderRadius: radius,
        border: Border.all(color: context.eq.line),
        boxShadow: Eq.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = Eq.violet, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
          ),
        ),
      ],
    ),
  );
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.text, {super.key, this.color = Eq.violet});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border(
        left: BorderSide(color: color.withValues(alpha: 0.55), width: 3),
      ),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, height: 1.5, color: context.eq.muted),
    ),
  );
}

// ------------------------------------------------------------------- buttons

enum BtnKind { primary, secondary, ghost, danger }

class EqButton extends StatelessWidget {
  const EqButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.kind = BtnKind.primary,
    this.busy = false,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final BtnKind kind;
  final bool busy;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = kind == BtnKind.primary;
    final fg = switch (kind) {
      BtnKind.primary => Colors.white,
      BtnKind.secondary => Eq.violetDeep,
      BtnKind.ghost => Eq.violet,
      BtnKind.danger => Eq.danger,
    };
    final disabled = onPressed == null || busy;
    final h = compact ? 40.0 : 52.0;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 17, color: fg),
        if (busy || icon != null) const SizedBox(width: 9),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 13.5 : 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (trailingIcon != null && !busy) ...[
          const SizedBox(width: 9),
          Icon(trailingIcon, size: 17, color: fg),
        ],
      ],
    );

    return Opacity(
      opacity: disabled && !busy ? 0.5 : 1,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          gradient: primary ? Eq.brandGradient : null,
          color: primary ? null : (kind == BtnKind.secondary ? context.eq.surface : Colors.transparent),
          borderRadius: BorderRadius.circular(compact ? 11 : 13),
          border: kind == BtnKind.secondary ? Border.all(color: context.eq.line) : null,
          boxShadow: primary && !disabled ? Eq.glow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 11 : 13),
            onTap: disabled
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- fields

/// Web-style field: label above the input.
class Labeled extends StatelessWidget {
  const Labeled(this.label, {super.key, required this.child, this.hint});
  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.eq.muted,
          ),
        ),
      ),
      child,
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            hint!,
            style: TextStyle(fontSize: 12, color: context.eq.faint, height: 1.4),
          ),
        ),
    ],
  );
}

class EqField extends StatelessWidget {
  const EqField({
    super.key,
    required this.label,
    this.controller,
    this.icon,
    this.hint,
    this.helper,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.maxLines = 1,
    this.formatters,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.suffixText,
  });

  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final String? hint;
  final String? helper;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final List<TextInputFormatter>? formatters;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final String? suffixText;

  @override
  Widget build(BuildContext context) => Labeled(
    label,
    hint: helper,
    child: TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      maxLines: maxLines,
      inputFormatters: formatters,
      autofocus: autofocus,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffixText,
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: context.eq.faint),
        suffixIcon: suffix,
      ),
    ),
  );
}

// -------------------------------------------------------------- filter tabs

class FilterTabs extends StatelessWidget {
  const FilterTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  final List<({String id, String label, int count})> items;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final it = items[i];
        final on = it.id == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(it.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: on ? Eq.violet : context.eq.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: on ? Eq.violet : context.eq.line),
            ),
            child: Row(
              children: [
                Text(
                  it.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: on ? Colors.white : context.eq.ink2,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: on ? Colors.white.withValues(alpha: 0.22) : context.eq.violetSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${it.count}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : Eq.violetDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ------------------------------------------------------------ state surfaces

class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.color = Eq.violet,
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
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: context.eq.ink2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.eq.muted,
              height: 1.5,
              fontSize: 14.5,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 22),
            EqButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    ),
  );
}

/// Server codes mapped to user-facing messages (DE/SL).
String errorMessage(Tr t, Object e) {
  if (e is! ApiException) return t('Etwas ist schiefgelaufen.', 'Nekaj je šlo narobe.');
  if (e.isOffline) return t('Keine Verbindung zum Server.', 'Ni povezave s strežnikom.');
  return switch (e.code) {
    'INVALID_LOGIN' => t(
      'E-Mail oder Passwort stimmt nicht.',
      'E-pošta ali geslo ni pravilno.',
    ),
    'MFA_REQUIRED' => t(
      'Bitte geben Sie den Code Ihrer Authenticator-App ein.',
      'Vnesite kodo iz aplikacije za overjanje.',
    ),
    'INVALID_MFA_CODE' => t('Der Code ist ungültig.', 'Koda ni veljavna.'),
    'INVALID_REGISTRATION' => t(
      'Bitte prüfen Sie Angaben und Passwort (mind. 12 Zeichen).',
      'Preverite podatke in geslo (vsaj 12 znakov).',
    ),
    'INVALID_COUNTRY' => t('Bitte wählen Sie ein Land.', 'Izberite državo.'),
    'INVALID_TOKEN' => t(
      'Der Link oder Code ist ungültig oder abgelaufen.',
      'Povezava ali koda je neveljavna ali potekla.',
    ),
    'INVALID_PASSWORD' => t(
      'Das Passwort erfüllt die Anforderungen nicht.',
      'Geslo ne izpolnjuje zahtev.',
    ),
    'EMAIL_NOT_VERIFIED' => t(
      'Bitte bestätigen Sie zuerst Ihre E-Mail-Adresse.',
      'Najprej potrdite e-poštni naslov.',
    ),
    'FINANCE_VERSION_CONFLICT' => t(
      'Die Daten wurden zwischenzeitlich geändert.',
      'Podatki so bili medtem spremenjeni.',
    ),
    'FINANCE_PLAN_UPGRADE_REQUIRED' => t(
      'Diese Funktion ist in Ihrem Paket nicht enthalten.',
      'Ta funkcija ni vključena v vaš paket.',
    ),
    'FINANCE_RELEASE_NOT_ENABLED' => t(
      'Finance ist außerhalb des Demo-Modus noch nicht freigegeben.',
      'Finance zunaj demo načina še ni sproščen.',
    ),
    'FINANCE_DUPLICATE_EXPENSE' => t(
      'Dieser Beleg wurde bereits erfasst.',
      'Ta račun je že evidentiran.',
    ),
    'FINANCE_INVALID_AMOUNT' => t(
      'Der Betrag ist ungültig.',
      'Znesek ni veljaven.',
    ),
    'FINANCE_INVALID_IBAN' => t('Die IBAN ist ungültig.', 'IBAN ni veljaven.'),
    'FINANCE_ALREADY_ISSUED' => t(
      'Das Dokument wurde bereits ausgestellt.',
      'Dokument je že izdan.',
    ),
    'FINANCE_ISSUE_BLOCKED' => t(
      'Ausstellung blockiert: Pflichtangaben fehlen.',
      'Izdaja blokirana: manjkajo obvezni podatki.',
    ),
    'FINANCE_INVALID_ATTACHMENT' => t(
      'Die Datei wird nicht unterstützt.',
      'Datoteka ni podprta.',
    ),
    'COMPANY_SUSPENDED' => t(
      'Dieses Unternehmen ist gesperrt.',
      'To podjetje je začasno onemogočeno.',
    ),
    _ when e.status == 429 => t(
      'Zu viele Versuche. Bitte warten Sie kurz.',
      'Preveč poskusov. Počakajte trenutek.',
    ),
    _ => t(
      'Die Anfrage konnte nicht abgeschlossen werden.',
      'Zahteve ni bilo mogoče dokončati.',
    ),
  };
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? LucideIcons.circleAlert : LucideIcons.circleCheck,
              size: 18,
              color: error ? const Color(0xFFFF9CB0) : const Color(0xFF8BE3BD),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

void showApiError(BuildContext context, Object e) {
  final lang = ProviderScope.containerOf(context).read(languageProvider);
  showSnack(context, errorMessage(Tr(lang), e), error: true);
}

class ErrorView extends ConsumerWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final e = error is ApiException ? error as ApiException : null;
    if (e != null && e.isOffline) {
      return StateMessage(
        icon: LucideIcons.wifiOff,
        title: t('Keine Verbindung', 'Ni povezave'),
        body: t(
          'Ihre Daten liegen sicher auf dem Server. Prüfen Sie die Verbindung und laden Sie erneut.',
          'Vaši podatki so varno na strežniku. Preverite povezavo in poskusite znova.',
        ),
        actionLabel: t('Erneut versuchen', 'Poskusi znova'),
        onAction: onRetry,
        color: Eq.warning,
      );
    }
    if (e != null && (e.status == 403 || e.isUpgrade)) {
      return StateMessage(
        icon: e.isUpgrade ? LucideIcons.sparkles : LucideIcons.lock,
        title: e.isUpgrade ? t('Im Paket nicht enthalten', 'Ni vključeno v paket') : t('Kein Zugriff', 'Ni dostopa'),
        body: errorMessage(t, e),
        color: e.isUpgrade ? Eq.violet : Eq.danger,
      );
    }
    if (e != null && e.isReleaseGate) {
      return StateMessage(
        icon: LucideIcons.shieldCheck,
        title: t('Noch nicht freigegeben', 'Še ni sproščeno'),
        body: errorMessage(t, e),
        color: Eq.warning,
      );
    }
    return StateMessage(
      icon: LucideIcons.circleAlert,
      title: t('Etwas ist schiefgelaufen', 'Nekaj je šlo narobe'),
      body: errorMessage(t, error),
      actionLabel: t('Erneut versuchen', 'Poskusi znova'),
      onAction: onRetry,
      color: Eq.danger,
    );
  }
}

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 80, this.radius = 16});
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
          const Color(0xFFEEE9F6),
          const Color(0xFFF8F5FD),
          _c.value,
        ),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 4, this.itemHeight = 92});
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

/// Standard data wrapper: skeleton while loading, mapped error states, pull-to-refresh.
class AsyncView<T> extends ConsumerWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
    this.loading,
  });
  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, T) builder;
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (value.isLoading && !value.hasValue) return loading ?? const LoadingList();
    if (value.hasError && !value.hasValue) return ErrorView(error: value.error!, onRetry: () => onRefresh());
    return RefreshIndicator(
      color: Eq.violet,
      onRefresh: onRefresh,
      child: builder(context, value.requireValue),
    );
  }
}

// ------------------------------------------------------------ progress ring

class CompletionRing extends StatelessWidget {
  const CompletionRing({super.key, required this.percent, required this.label});
  final int percent;
  final String label;
  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0, 100);
    return Semantics(
      label: label,
      value: '$value%',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 76,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: CircularProgressIndicator(
                  value: value / 100,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: context.eq.violetSoft,
                  color: Eq.violet,
                ),
              ),
              Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$value',
                        style: TextStyle(
                          color: context.eq.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.7,
                        ),
                      ),
                      TextSpan(
                        text: '%',
                        style: TextStyle(color: context.eq.muted, fontSize: 11, fontWeight: FontWeight.w500),
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

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.label,
    this.caption,
  });
  final double value;
  final double size;
  final String? label;
  final String? caption;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.clamp(0, 1)),
    duration: const Duration(milliseconds: 1100),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(v),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    label ?? '${(v * 100).round()}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                  if (label == null)
                    Padding(
                      padding: EdgeInsets.only(bottom: size * 0.04, left: 1),
                      child: Text(
                        '%',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: size * 0.12,
                        ),
                      ),
                    ),
                ],
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(8);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.12);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0xFFB9A2FF), Color(0xFF8A6BFF), Color(0xFFB9A2FF)],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ------------------------------------------------------------------- brand

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.3),
    child: Image.asset('assets/brand/equitensa.png', width: size, height: size),
  );
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      LogoMark(size: size + 8),
      const SizedBox(width: 10),
      Text(
        'Equitensa',
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.9,
        ),
      ),
    ],
  );
}
