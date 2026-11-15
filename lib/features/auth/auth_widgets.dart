import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/appearance.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../domain/models.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.radius = 24});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.eq.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: context.eq.line),
    ),
    child: child,
  );
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.error,
    this.hint,
    this.autofocus = false,
    this.maxLength,
    this.formatters,
    this.textCapitalization = TextCapitalization.none,
  });
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? error;
  final String? hint;
  final bool autofocus;
  final int? maxLength;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization textCapitalization;
  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();
  bool _hidden = true;
  @override
  void initState() {
    super.initState();
    _focus.addListener(_update);
  }

  void _update() => setState(() {});
  @override
  void dispose() {
    _focus.removeListener(_update);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: TextStyle(color: context.eq.ink, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 9),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: context.eq.page,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.error != null
                ? Eq.danger
                : _focus.hasFocus
                ? context.eq.accent
                : context.eq.line,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          obscureText: widget.obscure && _hidden,
          autocorrect: !widget.obscure && widget.keyboardType != TextInputType.emailAddress,
          enableSuggestions: !widget.obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          maxLength: widget.maxLength,
          inputFormatters: widget.formatters,
          textCapitalization: widget.textCapitalization,
          cursorColor: context.eq.accent,
          style: TextStyle(color: context.eq.ink, fontSize: 15),
          decoration: InputDecoration(
            counterText: '',
            filled: false,
            hintText: widget.hint,
            hintStyle: TextStyle(color: context.eq.faint),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            prefixIcon: widget.icon == null
                ? null
                : Icon(
                    widget.icon,
                    size: 18,
                    color: _focus.hasFocus ? context.eq.accent : context.eq.muted,
                  ),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Passwort anzeigen' : 'Passwort verbergen',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18,
                      color: context.eq.muted,
                    ),
                  )
                : null,
          ),
        ),
      ),
      if (widget.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(widget.error!, style: TextStyle(color: context.eq.error, fontSize: 12)),
        ),
    ],
  );
}

class StrengthMeter extends StatelessWidget {
  const StrengthMeter({super.key, required this.password, required this.t});
  final String password;
  final Tr t;
  static int level(String v) {
    if (v.length < 12) return 0;
    final score = [
      v.length >= 12,
      v.length >= 16,
      RegExp(r'[a-z]').hasMatch(v) && RegExp(r'[A-Z]').hasMatch(v),
      RegExp(r'\d').hasMatch(v),
      RegExp(r'[^A-Za-z0-9]').hasMatch(v),
    ].where((e) => e).length;
    return (score * 4 / 5).ceil().clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final strength = level(password);
    final color = strength < 2
        ? const Color(0xFFFFA0AA)
        : strength < 3
        ? const Color(0xFFE5C38B)
        : const Color(0xFF8ED9B9);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: i < strength ? color : context.eq.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            password.length < 12
                ? t('Mindestens 12 Zeichen', 'Vsaj 12 znakov')
                : '${t('Passwortstärke', 'Moč gesla')} · $strength/4',
            style: TextStyle(color: context.eq.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class CountryCards extends StatelessWidget {
  const CountryCards({super.key, required this.selected, required this.onSelect});
  final Country? selected;
  final ValueChanged<Country> onSelect;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final c in Country.values)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: c == Country.values.last ? 0 : 8),
            child: Semantics(
              selected: c == selected,
              child: Material(
                color: c == selected ? context.eq.violetSoft : context.eq.bg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(c);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c == selected ? context.eq.accent : context.eq.line),
                    ),
                    child: Column(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 10),
                        Text(
                          c.code,
                          style: TextStyle(color: context.eq.ink, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.eq.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class GlassButton extends StatelessWidget {
  const GlassButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: context.eq.ink,
        side: BorderSide(color: context.eq.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 9)],
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class AuthFrame extends ConsumerWidget {
  const AuthFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(authCountryProvider);
    return Scaffold(
      backgroundColor: context.eq.page,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.eq.bg, context.eq.page, context.eq.page],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
                child: Row(
                  children: [
                    Wordmark(size: 22, color: context.eq.ink),
                    const Spacer(),
                    const AppearanceButton(),
                    PopupMenuButton<Country>(
                      tooltip: 'Sprache / Jezik',
                      color: context.eq.surface,
                      onSelected: (c) => ref.read(authCountryProvider.notifier).set(c),
                      itemBuilder: (_) => [
                        for (final c in Country.values)
                          PopupMenuItem(
                            value: c,
                            child: Text('${c.flag}  ${c.label}', style: TextStyle(color: context.eq.ink)),
                          ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.eq.line),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.globe, color: context.eq.muted, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              country.language.toUpperCase(),
                              style: TextStyle(color: context.eq.ink, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Icon(LucideIcons.chevronDown, size: 12, color: context.eq.muted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final form = Center(
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child),
                    );
                    if (box.maxWidth < 900) return form;
                    return Row(
                      children: [
                        Expanded(
                          child: Padding(padding: const EdgeInsets.all(64), child: _AuthEditorial()),
                        ),
                        Container(width: 1, color: context.eq.line),
                        Expanded(child: form),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthEditorial extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker('EQUITENSA / PAY + FINANCE', color: context.eq.accent),
          const SizedBox(height: 30),
          Text(
            t('Mehr Klarheit.\nMehr Freiraum.', 'Več jasnosti.\nVeč svobode.'),
            style: TextStyle(
              color: context.eq.ink,
              fontSize: 64,
              height: 1.08,
              letterSpacing: -3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t('Ihr Unternehmen. Alles im Blick.', 'Vaše podjetje. Vse na enem mestu.'),
            style: TextStyle(color: context.eq.muted, fontSize: 19, height: 1.6),
          ),
          const SizedBox(height: 52),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: context.eq.line),
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: .025),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.layers, color: context.eq.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t('Ein Workspace. Alles verbunden.', 'En prostor. Vse povezano.'),
                        style: TextStyle(color: context.eq.ink, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  t(
                    'Rechnungen, Kontakte und Entgelttransparenz.\nIn Ihrer App und im Web.',
                    'Računi, stiki in transparentnost plač.\nV aplikaciji in na spletu.',
                  ),
                  style: TextStyle(color: context.eq.muted, fontSize: 15, height: 1.8),
                ),
                const SizedBox(height: 24),
                Divider(color: context.eq.line),
                const SizedBox(height: 18),
                Text(
                  'PAY     /     FINANCE',
                  style: TextStyle(color: context.eq.muted, fontSize: 12, letterSpacing: 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
