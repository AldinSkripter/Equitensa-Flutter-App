import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/files.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../finance/finance_common.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  late Future<Map<String, dynamic>> _loading;
  Map<String, dynamic>? _setup;
  List<String>? _codes;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<Map<String, dynamic>> _load() => ref.read(apiClientProvider).getJson('/auth/security');
  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    _setup = null;
    _codes = null;
    super.dispose();
  }

  Future<void> _perform(String action) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final t = trOf(ref);
    setState(() => _busy = true);
    try {
      final result = await ref.read(apiClientProvider).postJson('/auth/mfa/$action', {
        if (action != 'enable') 'password': _password.text,
        if (action != 'setup') 'code': _code.text.trim(),
      });
      if (!mounted) return;
      _password.clear();
      _code.clear();
      if (action == 'setup') {
        setState(() => _setup = result);
      } else {
        setState(() {
          _setup = null;
          _codes = action == 'enable' ? (result['backupCodes'] as List).cast<String>() : null;
          _loading = _load();
        });
        await ref.read(sessionProvider.notifier).refresh();
        if (mounted) {
          showSnack(
            context,
            action == 'enable'
                ? t('Zwei-Faktor-Anmeldung aktiviert.', 'Dvostopenjska prijava je vklopljena.')
                : t('Zwei-Faktor-Anmeldung deaktiviert.', 'Dvostopenjska prijava je izklopljena.'),
          );
        }
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    return PopScope(
      canPop: _codes == null,
      child: SubPage(
        kicker: 'Equitensa',
        title: t('Zwei-Faktor-Anmeldung', 'Dvostopenjska prijava'),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: EqButton(
                  expand: false,
                  label: t('Erneut versuchen', 'Poskusi znova'),
                  onPressed: () => setState(() => _loading = _load()),
                ),
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final security = snapshot.data!;
            final enabled = security['mfaEnabled'] == true;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                EqCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.shieldCheck, size: 30, color: context.eq.accent),
                      const SizedBox(height: 18),
                      Text(
                        enabled
                            ? t('Ihr Konto ist zusätzlich geschützt.', 'Vaš račun je dodatno zaščiten.')
                            : t('Ein weiterer Schutz für Ihr Konto.', 'Dodatna zaščita za vaš račun.'),
                        style: TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w600, color: context.eq.ink),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t(
                          'Verwenden Sie einen Code aus Ihrer Authenticator-App. Die Einstellung gilt auch für Ihre Anmeldung im Web.',
                          'Uporabite kodo iz aplikacije za preverjanje. Nastavitev velja tudi za prijavo na spletu.',
                        ),
                        style: TextStyle(color: context.eq.muted, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_codes != null) ...[
                  NoticeBanner(
                    t(
                      'Diese Wiederherstellungscodes werden nur einmal angezeigt. Jeder Code kann nur einmal verwendet werden.',
                      'Te kode za obnovitev so prikazane samo enkrat. Vsako lahko uporabite le enkrat.',
                    ),
                  ),
                  const SizedBox(height: 18),
                  EqCard(
                    child: SelectableText(
                      _codes!.join('\n'),
                      style: TextStyle(color: context.eq.ink, fontFamily: 'monospace', fontSize: 18, height: 1.8),
                    ),
                  ),
                  const SizedBox(height: 18),
                  EqButton(
                    label: t('Codes als Datei sichern', 'Shrani kode v datoteko'),
                    icon: LucideIcons.download,
                    onPressed: () async {
                      try {
                        await shareBytes(utf8.encode(_codes!.join('\n')), 'equitensa-recovery-codes.txt', 'text/plain');
                      } catch (error) {
                        if (context.mounted) showApiError(context, error);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  EqButton(
                    label: t('Codes gespeichert', 'Kode so shranjene'),
                    kind: BtnKind.secondary,
                    onPressed: () => setState(() => _codes = null),
                  ),
                ] else if (_setup != null) ...[
                  Text(
                    t('QR-Code scannen', 'Skenirajte kodo QR'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.eq.ink),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: QrImageView(data: _setup!['otpauth'] as String, size: 200, backgroundColor: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('Oder diesen Schlüssel manuell eingeben:', 'Ali ročno vnesite ta ključ:'),
                    style: TextStyle(color: context.eq.muted),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _setup!['secret'] as String,
                    style: TextStyle(color: context.eq.ink, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 24),
                  EqField(
                    label: t('Sechsstelliger Code', 'Šestmestna koda'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                  ),
                  const SizedBox(height: 18),
                  EqButton(
                    label: t('Bestätigen und aktivieren', 'Potrdi in vklopi'),
                    busy: _busy,
                    onPressed: () => _perform('enable'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _setup = null;
                            _code.clear();
                          }),
                    child: Text(t('Abbrechen', 'Prekliči')),
                  ),
                ] else ...[
                  if (enabled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        '${t('Verbleibende Wiederherstellungscodes', 'Preostale kode za obnovitev')}: ${security['backupCodesLeft']}',
                        style: TextStyle(color: context.eq.muted),
                      ),
                    ),
                  if (security['hasPassword'] == true) ...[
                    EqField(
                      label: t('Aktuelles Passwort', 'Trenutno geslo'),
                      controller: _password,
                      obscure: true,
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (enabled) ...[
                    EqField(
                      label: t(
                        'Authenticator- oder Wiederherstellungscode',
                        'Koda iz aplikacije ali koda za obnovitev',
                      ),
                      controller: _code,
                    ),
                    const SizedBox(height: 18),
                  ],
                  EqButton(
                    label: enabled
                        ? t('Zwei-Faktor-Anmeldung deaktivieren', 'Izklopi dvostopenjsko prijavo')
                        : t('Authenticator einrichten', 'Nastavi preverjanje'),
                    busy: _busy,
                    kind: enabled ? BtnKind.secondary : BtnKind.primary,
                    onPressed: () => _perform(enabled ? 'disable' : 'setup'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
