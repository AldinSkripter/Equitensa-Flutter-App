import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/appearance.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/api_client.dart';
import '../finance/finance_common.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final me = ref.watch(sessionProvider).value;
    if (me == null) return const SizedBox.shrink();
    final override = ref.watch(languageOverrideProvider);
    final api = ref.watch(apiClientProvider);

    return SubPage(
      kicker: 'Equitensa',
      title: t('Konto & Sicherheit', 'Račun in varnost'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: Eq.heroGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const LogoMark(size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.company.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${me.company.country.flag} ${me.company.country.label}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        me.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          EqCard(
            onTap: () => context.push('/account/brand'),
            child: Text(t('Unternehmensauftritt verwalten', 'Upravljanje predstavitve podjetja')),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              t(
                'Das Land ist das registrierte Unternehmensland und bestimmt die Regeln. Die Sprache ändert daran nichts.',
                'Država je registrirana država podjetja in določa pravila. Jezik tega ne spremeni.',
              ),
              style: TextStyle(
                color: context.eq.muted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
          SectionTitle(t('Darstellung', 'Videz')),
          const AppearanceSelector(),
          SectionTitle(t('Sprache', 'Jezik')),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.eq.violetSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (final (v, label) in [
                  (null as String?, t('Auto', 'Samodejno')),
                  ('de', 'Deutsch'),
                  ('sl', 'Slovenščina'),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(languageOverrideProvider.notifier).set(v),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: override == v ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: override == v ? Eq.cardShadow : null,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: override == v ? Eq.violet : context.eq.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SectionTitle(t('Sicherheit', 'Varnost')),
          _Row(
            LucideIcons.mailCheck,
            t('E-Mail', 'E-pošta'),
            me.emailVerified ? t('Bestätigt', 'Potrjeno') : t('Nicht bestätigt', 'Ni potrjeno'),
            me.emailVerified ? Eq.success : Eq.warning,
          ),
          const SizedBox(height: 10),
          _Row(
            LucideIcons.fingerprint,
            t('Zwei-Faktor-Anmeldung', 'Dvostopenjska prijava'),
            me.mfaEnabled ? t('Aktiv', 'Aktivno') : t('Nicht eingerichtet', 'Ni nastavljeno'),
            me.mfaEnabled ? Eq.success : context.eq.muted,
          ),
          const SizedBox(height: 10),
          EqCard(
            onTap: () => context.push('/account/security'),
            child: Row(
              children: [
                const Icon(LucideIcons.shieldCheck, color: Eq.violet, size: 20),
                const SizedBox(width: 14),
                Expanded(child: Text(t('Zwei-Faktor-Anmeldung verwalten', 'Upravljaj dvostopenjsko prijavo'))),
                Icon(LucideIcons.chevronRight, size: 18, color: context.eq.faint),
              ],
            ),
          ),
          const SizedBox(height: 10),
          EqCard(
            onTap: () => _passwordSheet(context, ref),
            child: Row(
              children: [
                const Icon(LucideIcons.keyRound, color: Eq.violet, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    t('Passwort ändern', 'Spremeni geslo'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.eq.ink2,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 18, color: context.eq.faint),
              ],
            ),
          ),
          SectionTitle(t('Verbindung', 'Povezava')),
          EqCard(
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Eq.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        api.baseUrl.isEmpty
                            ? t(
                                'Gleicher Server wie Web',
                                'Isti strežnik kot splet',
                              )
                            : api.baseUrl,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.eq.ink2,
                        ),
                      ),
                      Text(
                        me.demo
                            ? t(
                                'Lokale Demo-Umgebung · synthetische Daten',
                                'Lokalno demo okolje · sintetični podatki',
                              )
                            : t('Verbunden', 'Povezano'),
                        style: TextStyle(color: context.eq.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          NoticeBanner(
            t(
              'Entwicklungs-Anmeldung per Web-Sitzung. Die native Anmeldung (OAuth/PKCE) folgt, sobald das Backend sie bereitstellt.',
              'Razvojna prijava prek spletne seje. Nativna prijava (OAuth/PKCE) sledi, ko jo strežnik zagotovi.',
            ),
          ),
          const SizedBox(height: 22),
          EqButton(
            kind: BtnKind.danger,
            label: t('Abmelden', 'Odjava'),
            icon: LucideIcons.logOut,
            onPressed: () async {
              await ref.read(sessionProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.title, this.value, this.color);
  final IconData icon;
  final String title, value;
  final Color color;

  @override
  Widget build(BuildContext context) => EqCard(
    child: Row(
      children: [
        Icon(icon, color: Eq.violet, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, color: context.eq.ink2),
          ),
        ),
        Pill(value, color: color),
      ],
    ),
  );
}

Future<void> _passwordSheet(BuildContext context, WidgetRef ref) {
  final t = trOf(ref);
  final current = TextEditingController();
  final next = TextEditingController();
  var busy = false;
  String? error;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Passwort ändern', 'Spremeni geslo'),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: context.eq.ink2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t(
                'Andere Geräte werden danach abgemeldet.',
                'Druge naprave bodo nato odjavljene.',
              ),
              style: TextStyle(color: context.eq.muted),
            ),
            const SizedBox(height: 18),
            EqField(
              label: t('Aktuelles Passwort', 'Trenutno geslo'),
              controller: current,
              obscure: true,
            ),
            const SizedBox(height: 14),
            EqField(
              label: t('Neues Passwort', 'Novo geslo'),
              controller: next,
              obscure: true,
              helper: t('Mindestens 12 Zeichen', 'Vsaj 12 znakov'),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              NoticeBanner(error!, color: Eq.danger),
            ],
            const SizedBox(height: 18),
            EqButton(
              label: t('Passwort speichern', 'Shrani geslo'),
              busy: busy,
              onPressed: () async {
                if (next.text.length < 12) {
                  setS(
                    () => error = t('Mindestens 12 Zeichen.', 'Vsaj 12 znakov.'),
                  );
                  return;
                }
                setS(() {
                  busy = true;
                  error = null;
                });
                try {
                  await ref.read(apiClientProvider).postJson('/auth/password', {
                    'password': current.text,
                    'newPassword': next.text,
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    showSnack(
                      context,
                      t('Passwort geändert.', 'Geslo spremenjeno.'),
                    );
                  }
                } on ApiException catch (e) {
                  setS(() => error = errorMessage(t, e));
                } finally {
                  if (ctx.mounted) setS(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
