import 'dart:async';

import 'package:fcourt/app/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restores a saved mode and falls back for an unknown preference',
    () async {
      final saved = ThemeController(read: () async => 'dark');
      addTearDown(saved.dispose);
      await saved.restore();
      expect(saved.mode, ThemeMode.dark);
      final unknown = ThemeController(read: () async => 'old-value');
      addTearDown(unknown.dispose);
      await unknown.restore();
      expect(unknown.mode, ThemeMode.light);
    },
  );

  test('a slow restore cannot overwrite a new selection', () async {
    final read = Completer<String?>();
    final controller = ThemeController(
      read: () => read.future,
      write: (_) async {},
    );
    addTearDown(controller.dispose);
    final restore = controller.restore();
    await controller.select(ThemeMode.light);
    read.complete('dark');
    await restore;
    expect(controller.mode, ThemeMode.light);
  });

  test(
    'serializes writes so rapid selections persist the last choice',
    () async {
      final first = Completer<void>();
      final writes = <String>[];
      final controller = ThemeController(
        write: (value) async {
          if (value == 'light') await first.future;
          writes.add(value);
        },
      );
      addTearDown(controller.dispose);
      final light = controller.select(ThemeMode.light);
      final dark = controller.select(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);
      first.complete();
      expect(await light, isTrue);
      expect(await dark, isTrue);
      expect(writes, ['light', 'dark']);
    },
  );

  test(
    'storage failures leave the app usable and report an unsaved choice',
    () async {
      final controller = ThemeController(
        read: () async => throw Exception('unavailable'),
        write: (_) async => throw Exception('unavailable'),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(controller.mode, ThemeMode.light);
      expect(await controller.select(ThemeMode.dark), isFalse);
      expect(controller.mode, ThemeMode.dark);
    },
  );

  test('finishing a restore after disposal does not notify', () async {
    final read = Completer<String?>();
    final controller = ThemeController(read: () => read.future);
    final restore = controller.restore();
    controller.dispose();
    read.complete('dark');
    await restore;
  });
}
