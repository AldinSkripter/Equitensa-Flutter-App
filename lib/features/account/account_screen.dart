import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final company = ref.watch(sessionProvider);
    if (company == null) return const SizedBox.shrink();
    final override = ref.watch(languageOverrideProvider);
    final flags = ref.watch(demoFlagsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('account'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                const BrandMark(size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${company.country.flag} ${company.country.label} · ${company.city}',
                        style: const TextStyle(color: Brand.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              s.t('country_note'),
              style: const TextStyle(
                color: Brand.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          SectionTitle(s.t('language')),
          SegmentedButton<String?>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: null, label: Text(s.t('lang_auto'))),
              const ButtonSegment(value: 'de', label: Text('DE')),
              const ButtonSegment(value: 'sl', label: Text('SL')),
              const ButtonSegment(value: 'en', label: Text('EN')),
            ],
            selected: {override},
            onSelectionChanged: (v) =>
                ref.read(languageOverrideProvider.notifier).set(v.first),
          ),
          SectionTitle(s.t('workspace')),
          _Tile(
            icon: Icons.workspace_premium_rounded,
            title: s.t('packages'),
            subtitle: company.plan == null
                ? s.t('not_activated')
                : s.t('current_plan'),
            onTap: () => context.push('/packages'),
          ),
          const SizedBox(height: 10),
          _Tile(
            icon: Icons.shield_outlined,
            title: s.t('security'),
            subtitle: s.t('security_hint'),
            onTap: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(s.t('auth_pending')))),
          ),
          SectionTitle(s.t('demo_tools')),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  value: flags.offline,
                  activeThumbColor: Brand.violet,
                  title: Text(s.t('sim_offline')),
                  onChanged: (v) =>
                      ref.read(demoFlagsProvider.notifier).setOffline(v),
                ),
                const Divider(),
                SwitchListTile(
                  value: flags.conflict,
                  activeThumbColor: Brand.violet,
                  title: Text(s.t('sim_conflict')),
                  onChanged: (v) =>
                      ref.read(demoFlagsProvider.notifier).setConflict(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Brand.danger),
            onPressed: () {
              ref.read(languageOverrideProvider.notifier).set(null);
              ref.read(demoFlagsProvider.notifier)
                ..setOffline(false)
                ..setConflict(false);
              ref.read(sessionProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(s.t('logout')),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, color: Brand.violet),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: const TextStyle(color: Brand.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Brand.muted),
      ],
    ),
  );
}
