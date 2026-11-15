import 'dart:async';

import 'package:equitensa/core/appearance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Store implements AppearanceStore {
  String? value;
  Completer<String?>? delayedRead;
  @override
  Future<String?> read() => delayedRead?.future ?? Future.value(value);
  @override
  Future<void> write(String mode) async {
    value = mode;
  }
}

void main() {
  test('appearance is restored across application restarts', () async {
    final store = _Store();
    final first = ProviderContainer(overrides: [appearanceStoreProvider.overrideWithValue(store)]);
    await first.read(appearanceProvider.notifier).set(ThemeMode.dark);
    expect(store.value, 'dark');
    first.dispose();
    final second = ProviderContainer(overrides: [appearanceStoreProvider.overrideWithValue(store)]);
    addTearDown(second.dispose);
    second.read(appearanceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(appearanceProvider), ThemeMode.dark);
  });

  test('a slow stored preference cannot overwrite a new choice', () async {
    final store = _Store()..delayedRead = Completer<String?>();
    final container = ProviderContainer(overrides: [appearanceStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    container.read(appearanceProvider);
    await container.read(appearanceProvider.notifier).set(ThemeMode.dark);
    store.delayedRead!.complete('light');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appearanceProvider), ThemeMode.dark);
  });

  test('an unknown preference falls back to the system', () async {
    final store = _Store()..value = 'obsolete';
    final container = ProviderContainer(overrides: [appearanceStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    container.read(appearanceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appearanceProvider), ThemeMode.system);
  });
}
