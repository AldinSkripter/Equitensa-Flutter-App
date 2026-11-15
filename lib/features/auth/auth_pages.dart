import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/api_client.dart';
import 'auth_widgets.dart';
import 'intro_page.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

final demoBackendProvider = FutureProvider<bool>(
  (ref) => ref.read(repositoryProvider).isDemoBackend(),
);

extension _Stagger on Widget {
  Widget rise(int i) => animate(delay: (80 * i).ms)
      .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
      .slideY(
        begin: 0.14,
        end: 0,
        duration: 550.ms,
        curve: Curves.easeOutCubic,
      );
}

class _Head extends StatelessWidget {
  const _Head({required this.kicker, required this.title, this.subtitle});
  final String kicker;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Kicker(kicker, color: context.eq.accent),
      const SizedBox(height: 10),
      Text(
        title,
        style: TextStyle(
          color: context.eq.ink,
          fontSize: 38,
          height: 1.12,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 10),
        Text(
          subtitle!,
          style: TextStyle(
            color: context.eq.ink.withValues(alpha: 0.7),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    ],
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: context.eq.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(
        color: context.eq.error.withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          LucideIcons.circleAlert,
          size: 18,
          color: context.eq.error,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.eq.error,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 200.ms).shakeX(hz: 4, amount: 5, duration: 380.ms);
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.lead, this.link, this.onTap);
  final String lead;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$lead ',
                style: TextStyle(color: context.eq.ink.withValues(alpha: 0.62)),
              ),
              TextSpan(
                text: link,
                style: TextStyle(
                  color: context.eq.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ welcome

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoBackendProvider).value == true;
    return IntroPage(onDemo: demo ? () => _demoSheet(context, ref) : null);
  }
}

Future<void> _demoSheet(BuildContext context, WidgetRef ref) {
  final t = trOf(ref);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1B1430),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Synthetische Demo-Firma', 'Sintetično demo podjetje'),
              style: TextStyle(
                color: context.eq.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'Nur für die lokale Entwicklung. Wählen Sie das Land des Demo-Unternehmens.',
                'Samo za lokalni razvoj. Izberite državo demo podjetja.',
              ),
              style: TextStyle(
                color: context.eq.ink.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            CountryCards(
              selected: null,
              onSelect: (c) async {
                Navigator.of(ctx).pop();
                try {
                  await ref.read(sessionProvider.notifier).startDemo(c);
                } catch (e) {
                  if (context.mounted) showApiError(context, e);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// -------------------------------------------------------------------- login

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _mfa = false;
  String? _error;
  String? _emailError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final t = trOf(ref);
    final email = _email.text.trim();
    setState(() {
      _error = null;
      _emailError = _emailRe.hasMatch(email)
          ? null
          : t(
              'Bitte eine gültige E-Mail eingeben.',
              'Vnesite veljaven e-poštni naslov.',
            );
    });
    if (_emailError != null || _password.text.isEmpty) {
      if (_password.text.isEmpty) {
        setState(
          () => _error = t('Bitte Passwort eingeben.', 'Vnesite geslo.'),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).login(email, _password.text, code: _mfa ? _code.text : null);
      HapticFeedback.mediumImpact();
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        if (e.code == 'MFA_REQUIRED') _mfa = true;
        _error = errorMessage(t, e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        18,
        24,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackRow(onTap: () => context.go('/welcome')),
          const SizedBox(height: 14),
          _Head(
            kicker: t('Willkommen zurück', 'Dobrodošli nazaj'),
            title: t('Anmelden', 'Prijava'),
            subtitle: t(
              'Ihre Daten, Berichte und Rechnungen – genau so, wie Sie sie im Web verlassen haben.',
              'Vaši podatki, poročila in računi – točno tako, kot ste jih pustili na spletu.',
            ),
          ).rise(0),
          const SizedBox(height: 24),
          GlassCard(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthField(
                    label: t('Geschäftliche E-Mail', 'Poslovna e-pošta'),
                    controller: _email,
                    icon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    error: _emailError,
                    hint: 'name@firma.at',
                  ),
                  const SizedBox(height: 16),
                  AuthField(
                    label: t('Passwort', 'Geslo'),
                    controller: _password,
                    icon: LucideIcons.keyRound,
                    obscure: true,
                    textInputAction: _mfa ? TextInputAction.next : TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _mfa ? null : _submit(),
                  ),
                  AnimatedSize(
                    duration: 300.ms,
                    curve: Curves.easeOutCubic,
                    child: _mfa
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: AuthField(
                              label: t(
                                'Authenticator-Code',
                                'Koda za overjanje',
                              ),
                              controller: _code,
                              icon: LucideIcons.fingerprint,
                              keyboardType: TextInputType.number,
                              maxLength: 8,
                              autofocus: true,
                              onSubmitted: (_) => _submit(),
                              formatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9A-Za-z-]'),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/forgot'),
                      child: Text(
                        t('Passwort vergessen?', 'Ste pozabili geslo?'),
                        style: TextStyle(
                          color: context.eq.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    _ErrorBanner(_error!),
                    const SizedBox(height: 14),
                  ],
                  EqButton(
                    label: t('Anmelden', 'Prijava'),
                    trailingIcon: LucideIcons.arrowRight,
                    busy: _busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ).rise(1),
          const SizedBox(height: 14),
          _LinkText(
            t('Noch kein Konto?', 'Še nimate računa?'),
            t('Konto erstellen', 'Ustvari račun'),
            () => context.go('/register'),
          ).rise(2),
        ],
      ),
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: const Icon(LucideIcons.arrowLeft, size: 18, color: Colors.white),
      ),
    ),
  );
}

// ----------------------------------------------------------------- register

// ------------------------------------------------------------ verify e-mail

String _extractToken(String raw) {
  final text = raw.trim();
  final m = RegExp(r'[?&]token=([A-Za-z0-9_\-]+)').firstMatch(text);
  if (m != null) return m.group(1)!;
  final tail = RegExp(r'([A-Za-z0-9_\-]{20,})\s*$').firstMatch(text);
  return tail?.group(1) ?? text;
}

class VerifyPage extends ConsumerStatefulWidget {
  const VerifyPage({super.key});

  @override
  ConsumerState<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends ConsumerState<VerifyPage> {
  final _token = TextEditingController();
  Timer? _cooldown;
  int _wait = 0;
  bool _busy = false;
  bool _checking = false;
  bool _manual = false;
  String? _error;

  @override
  void dispose() {
    _cooldown?.cancel();
    _token.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    final t = trOf(ref);
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).resendVerification();
      if (!mounted) return;
      showSnack(
        context,
        t('Bestätigungslink gesendet.', 'Potrditvena povezava poslana.'),
      );
      setState(() => _wait = 45);
      _cooldown?.cancel();
      _cooldown = Timer.periodic(1.seconds, (tm) {
        if (_wait <= 1) tm.cancel();
        if (mounted) setState(() => _wait = math.max(0, _wait - 1));
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final t = trOf(ref);
    setState(() => _checking = true);
    try {
      final me = await ref.read(sessionProvider.notifier).refresh();
      if (mounted && me != null && !me.emailVerified) {
        showSnack(
          context,
          t(
            'Noch nicht bestätigt. Bitte öffnen Sie den Link in Ihrer E-Mail.',
            'Še ni potrjeno. Odprite povezavo v e-pošti.',
          ),
          error: true,
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submitToken() async {
    final t = trOf(ref);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).verifyEmail(_extractToken(_token.text));
      await ref.read(sessionProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final me = ref.watch(sessionProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child:
                Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        gradient: Eq.brandGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Eq.violet.withValues(alpha: 0.55),
                            blurRadius: 40,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.mailCheck,
                        size: 42,
                        color: Colors.white,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: -4,
                      end: 4,
                      duration: 2200.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          const SizedBox(height: 26),
          _Head(
            kicker: t('E-Mail bestätigen', 'Potrditev e-pošte'),
            title: t('Prüfen Sie Ihr Postfach', 'Preverite svoj nabiralnik'),
            subtitle: t(
              'Wir haben einen Bestätigungslink an ${me?.email ?? ''} gesendet. Öffnen Sie ihn, dann geht es hier automatisch weiter.',
              'Potrditveno povezavo smo poslali na ${me?.email ?? ''}. Odprite jo in nadaljevali boste tukaj.',
            ),
          ).rise(0),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EqButton(
                  label: t('Ich habe bestätigt', 'Potrdil sem'),
                  icon: LucideIcons.check,
                  busy: _checking,
                  onPressed: _check,
                ),
                const SizedBox(height: 12),
                GlassButton(
                  label: _wait > 0
                      ? '${t('Erneut senden in', 'Ponovno pošlji čez')} ${_wait}s'
                      : t('Link erneut senden', 'Ponovno pošlji povezavo'),
                  icon: LucideIcons.send,
                  onPressed: _busy || _wait > 0 ? null : _resend,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _manual = !_manual),
                  child: Text(
                    t(
                      'Link oder Code manuell einfügen',
                      'Ročno prilepi povezavo ali kodo',
                    ),
                    style: TextStyle(
                      color: context.eq.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                  child: _manual
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            AuthField(
                              label: t(
                                'Bestätigungslink',
                                'Potrditvena povezava',
                              ),
                              controller: _token,
                              icon: LucideIcons.link,
                              hint: 'https://…?token=…',
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 14),
                            if (_error != null) ...[
                              _ErrorBanner(_error!),
                              const SizedBox(height: 12),
                            ],
                            EqButton(
                              label: t('Bestätigen', 'Potrdi'),
                              busy: _busy,
                              onPressed: _token.text.trim().isEmpty ? null : _submitToken,
                            ),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ).rise(1),
          const SizedBox(height: 8),
          _LinkText(
            t('Falsches Konto?', 'Napačen račun?'),
            t('Abmelden', 'Odjava'),
            () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- forgot / reset

class ForgotPage extends ConsumerStatefulWidget {
  const ForgotPage({super.key});

  @override
  ConsumerState<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends ConsumerState<ForgotPage> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = trOf(ref);
    if (!_emailRe.hasMatch(_email.text.trim())) {
      setState(
        () => _error = t(
          'Bitte eine gültige E-Mail eingeben.',
          'Vnesite veljaven e-poštni naslov.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).forgotPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackRow(onTap: () => context.go('/login')),
          const SizedBox(height: 14),
          _Head(
            kicker: t('Konto-Hilfe', 'Pomoč pri računu'),
            title: _sent
                ? t('Link unterwegs', 'Povezava je na poti')
                : t('Passwort zurücksetzen', 'Ponastavitev gesla'),
            subtitle: _sent
                ? t(
                    'Falls ein Konto zu dieser Adresse existiert, haben wir einen Link gesendet. Aus Datenschutzgründen bestätigen wir das nicht.',
                    'Če za ta naslov obstaja račun, smo poslali povezavo. Iz zasebnostnih razlogov tega ne potrjujemo.',
                  )
                : t(
                    'Wir senden Ihnen einen Link zum Festlegen eines neuen Passworts.',
                    'Poslali vam bomo povezavo za nastavitev novega gesla.',
                  ),
          ).rise(0),
          const SizedBox(height: 24),
          GlassCard(
            child: _sent
                ? Column(
                    children: [
                      EqButton(
                        label: t(
                          'Ich habe einen Link erhalten',
                          'Povezavo sem prejel',
                        ),
                        trailingIcon: LucideIcons.arrowRight,
                        onPressed: () => context.go('/reset'),
                      ),
                      const SizedBox(height: 12),
                      GlassButton(
                        label: t('Zur Anmeldung', 'Na prijavo'),
                        onPressed: () => context.go('/login'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthField(
                        label: t('Geschäftliche E-Mail', 'Poslovna e-pošta'),
                        controller: _email,
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => _send(),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        _ErrorBanner(_error!),
                        const SizedBox(height: 14),
                      ],
                      EqButton(
                        label: t('Link senden', 'Pošlji povezavo'),
                        icon: LucideIcons.send,
                        busy: _busy,
                        onPressed: _send,
                      ),
                    ],
                  ),
          ).rise(1),
        ],
      ),
    );
  }
}

class ResetPage extends ConsumerStatefulWidget {
  const ResetPage({super.key});

  @override
  ConsumerState<ResetPage> createState() => _ResetPageState();
}

class _ResetPageState extends ConsumerState<ResetPage> {
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = trOf(ref);
    if (_token.text.trim().isEmpty || _password.text.length < 12) {
      setState(
        () => _error = t(
          'Link/Code und ein Passwort mit mind. 12 Zeichen sind erforderlich.',
          'Potrebni sta povezava/koda in geslo z vsaj 12 znaki.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).resetPassword(_extractToken(_token.text), _password.text);
      if (!mounted) return;
      showSnack(
        context,
        t(
          'Passwort geändert. Bitte neu anmelden.',
          'Geslo spremenjeno. Prijavite se znova.',
        ),
      );
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackRow(onTap: () => context.go('/forgot')),
          const SizedBox(height: 14),
          _Head(
            kicker: t('Konto-Hilfe', 'Pomoč pri računu'),
            title: t('Neues Passwort', 'Novo geslo'),
            subtitle: t(
              'Fügen Sie den Link aus Ihrer E-Mail ein und legen Sie ein neues Passwort fest.',
              'Prilepite povezavo iz e-pošte in nastavite novo geslo.',
            ),
          ).rise(0),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthField(
                  label: t('Link aus der E-Mail', 'Povezava iz e-pošte'),
                  controller: _token,
                  icon: LucideIcons.link,
                  hint: 'https://…?token=…',
                ),
                const SizedBox(height: 16),
                AuthField(
                  label: t('Neues Passwort', 'Novo geslo'),
                  controller: _password,
                  icon: LucideIcons.keyRound,
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                ),
                StrengthMeter(password: _password.text, t: t),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  _ErrorBanner(_error!),
                  const SizedBox(height: 14),
                ],
                EqButton(
                  label: t('Passwort speichern', 'Shrani geslo'),
                  icon: LucideIcons.check,
                  busy: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ).rise(1),
        ],
      ),
    );
  }
}
