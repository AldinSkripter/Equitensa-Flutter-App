import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'i18n.dart';

abstract interface class AppearanceStore {
  Future<String?> read();
  Future<void> write(String mode);
}

class SecureAppearanceStore implements AppearanceStore {
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: 'equitensa_appearance');
  @override
  Future<void> write(String mode) => _storage.write(key: 'equitensa_appearance', value: mode);
}

final appearanceStoreProvider = Provider<AppearanceStore>((ref) => SecureAppearanceStore());

class AppearanceController extends Notifier<ThemeMode> {
  int _revision = 0;
  Future<void> _pendingWrite = Future.value();
  @override
  ThemeMode build() {
    unawaited(_restore(ref.read(appearanceStoreProvider), _revision));
    return ThemeMode.system;
  }

  Future<void> _restore(AppearanceStore store, int revision) async {
    try {
      final value = await store.read();
      if (!ref.mounted || revision != _revision) return;
      state = ThemeMode.values.firstWhere((mode) => mode.name == value, orElse: () => ThemeMode.system);
    } catch (_) {
      /* An unavailable keychain never blocks the app. */
    }
  }

  Future<void> set(ThemeMode mode) async {
    _revision++;
    state = mode;
    final store = ref.read(appearanceStoreProvider);
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await store.write(mode.name);
      } catch (_) {
        /* Keep this session's choice. */
      }
    });
    await _pendingWrite;
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, ThemeMode>(AppearanceController.new);

class AppearanceButton extends ConsumerWidget {
  const AppearanceButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    final mode = ref.watch(appearanceProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: t('Darstellung', 'Videz'),
      initialValue: mode,
      icon: Icon(
        mode == ThemeMode.system
            ? LucideIcons.monitor
            : mode == ThemeMode.dark
            ? LucideIcons.moon
            : LucideIcons.sun,
        size: 18,
      ),
      onSelected: (value) => ref.read(appearanceProvider.notifier).set(value),
      itemBuilder: (_) => [
        for (final option in [
          (ThemeMode.system, t('System', 'Sistem')),
          (ThemeMode.light, t('Hell', 'Svetlo')),
          (ThemeMode.dark, t('Dunkel', 'Temno')),
        ])
          PopupMenuItem(
            value: option.$1,
            child: Row(
              children: [
                Expanded(child: Text(option.$2)),
                if (mode == option.$1) const Icon(LucideIcons.check, size: 16),
              ],
            ),
          ),
      ],
    );
  }
}

class AppearanceSelector extends ConsumerWidget {
  const AppearanceSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text(t('System', 'Sistem')),
          icon: const Icon(LucideIcons.monitor, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text(t('Hell', 'Svetlo')),
          icon: const Icon(LucideIcons.sun, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text(t('Dunkel', 'Temno')),
          icon: const Icon(LucideIcons.moon, size: 16),
        ),
      ],
      selected: {ref.watch(appearanceProvider)},
      onSelectionChanged: (values) => ref.read(appearanceProvider.notifier).set(values.single),
    );
  }
}
