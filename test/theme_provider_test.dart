import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_tracker/features/settings/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('unknown saved theme falls back to system', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'unknown'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });
  test(
    'theme persists across containers and serializes rapid changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      expect(container.read(themeModeProvider), ThemeMode.system);
      final controller = container.read(themeModeProvider.notifier);
      final lightSave = controller.setMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
      final darkSave = controller.setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await Future.wait([lightSave, darkSave]);
      container.dispose();
      final reopened = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(reopened.dispose);
      expect(reopened.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');
    },
  );
}
