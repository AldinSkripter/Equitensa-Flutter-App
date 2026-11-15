import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'i18n.dart';
import 'theme.dart';

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
    return ThemeMode.light;
  }

  Future<void> _restore(AppearanceStore store, int revision) async {
    try {
      final value = await store.read();
      if (!ref.mounted || revision != _revision) return;
      state = value == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      /* An unavailable keychain never blocks the app. */
    }
  }

  Future<void> set(ThemeMode mode) async {
    mode = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
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
    final dark = mode == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton.outlined(
        tooltip: dark ? t('Light Mode', 'Svetli način') : t('Dark Mode', 'Temni način'),
        onPressed: () => ref.read(appearanceProvider.notifier).set(dark ? ThemeMode.light : ThemeMode.dark),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: context.eq.surface,
          foregroundColor: context.eq.accent,
          side: BorderSide(color: context.eq.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(dark ? LucideIcons.sun : LucideIcons.moon, key: ValueKey(dark), size: 18),
        ),
      ),
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
          value: ThemeMode.light,
          label: Text(t('Light', 'Svetlo')),
          icon: const Icon(LucideIcons.sun, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text(t('Dark', 'Temno')),
          icon: const Icon(LucideIcons.moon, size: 16),
        ),
      ],
      selected: {ref.watch(appearanceProvider)},
      onSelectionChanged: (values) => ref.read(appearanceProvider.notifier).set(values.single),
    );
  }
}
