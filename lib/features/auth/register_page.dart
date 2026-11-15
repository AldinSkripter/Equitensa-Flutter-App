import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/ui.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';
import 'auth_widgets.dart';

/// The same fields, ordering and registration contract as the web AccountForm.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _errors = <String, String>{};
  late Country _country;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _country = ref.read(authCountryProvider);
  }

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final t = trOf(ref);
    _errors.clear();
    if (_company.text.trim().isEmpty) {
      _errors['company'] = t('Bitte Unternehmensnamen eingeben.', 'Vnesite ime podjetja.');
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      _errors['email'] = t('Bitte eine gültige E-Mail eingeben.', 'Vnesite veljaven e-poštni naslov.');
    }
    if (_password.text.length < 12) {
      _errors['password'] = t('Mindestens 12 Zeichen.', 'Vsaj 12 znakov.');
    }
    setState(() => _error = null);
    if (_errors.isNotEmpty) {
      // Bring the first invalid field into view when the keyboard covers the form.
      final formContext = _formKey.currentContext;
      if (formContext != null) {
        await Scrollable.ensureVisible(formContext, duration: const Duration(milliseconds: 250));
      }
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .register(
            companyName: _company.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            country: _country,
          );
      if (mounted) {
        TextInput.finishAutofillContext();
        HapticFeedback.mediumImpact();
      }
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/welcome'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFBBB7CA), padding: EdgeInsets.zero),
            icon: const Icon(LucideIcons.arrowLeft, size: 16),
            label: Text(t('Zurück', 'Nazaj')),
          ),
          const SizedBox(height: 18),
          Kicker(t('IHR EQUITENSA-KONTO', 'VAŠ RAČUN EQUITENSA'), color: const Color(0xFFC6B6FF)),
          const SizedBox(height: 12),
          Text(
            t('Konto erstellen', 'Ustvari račun'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              letterSpacing: -1.2,
              height: 1.12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'Zuerst Ihr Unternehmenskonto. Ein Zugang für die App und das Web.',
              'Najprej račun vašega podjetja. En dostop za aplikacijo in splet.',
            ),
            style: const TextStyle(color: Color(0xFFAAA9B7), fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 24),
          GlassCard(
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthField(
                      label: t('Unternehmensname', 'Ime podjetja'),
                      controller: _company,
                      icon: LucideIcons.building2,
                      maxLength: 255,
                      autofillHints: const [AutofillHints.organizationName],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      error: _errors['company'],
                    ),
                    const SizedBox(height: 18),
                    AuthField(
                      label: t('Geschäftliche E-Mail', 'Poslovna e-pošta'),
                      controller: _email,
                      icon: LucideIcons.mail,
                      maxLength: 255,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      error: _errors['email'],
                    ),
                    const SizedBox(height: 18),
                    AuthField(
                      label: t('Passwort', 'Geslo'),
                      controller: _password,
                      icon: LucideIcons.keyRound,
                      obscure: true,
                      maxLength: 128,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      error: _errors['password'],
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                    StrengthMeter(password: _password.text, t: t),
                    const SizedBox(height: 26),
                    Text(
                      t('Land Ihres Unternehmens (Berichtsland)', 'Država vašega podjetja (država poročanja)'),
                      style: const TextStyle(color: Color(0xFFE0DFE7), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    CountryCards(
                      selected: _country,
                      onSelect: (c) {
                        if (_busy) return;
                        setState(() => _country = c);
                        ref.read(authCountryProvider.notifier).set(c);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t(
                        'Bestimmt Berichtsregeln und -sprache. Später nicht änderbar; eine Gesellschaft pro Konto.',
                        'Določa pravila in jezik poročila. Pozneje ni spremenljivo; ena družba na račun.',
                      ),
                      style: const TextStyle(color: Color(0xFFAAA9B7), fontSize: 11, height: 1.6),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFFF9CB0), fontSize: 13, height: 1.5),
                          ),
                        ),
                      ),
                    const SizedBox(height: 26),
                    EqButton(
                      label: t('Konto erstellen & weiter', 'Ustvarite račun in nadaljujte'),
                      trailingIcon: LucideIcons.arrowRight,
                      busy: _busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                t('Schon ein Konto? Anmelden', 'Že imate račun? Prijava'),
                style: const TextStyle(color: Color(0xFFC6B6FF), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
