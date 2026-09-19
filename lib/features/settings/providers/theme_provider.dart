import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences must be initialized before runApp'),
);
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  /// SharedPreferences 中的主题键。
  static const storageKey = 'theme_mode';

  /// 上一次保存任务，用于串行化连续修改。
  Future<void> _pending = Future<void>.value();
  @override
  ThemeMode build() =>
      switch (ref.watch(preferencesProvider).getString(storageKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  Future<void> setMode(ThemeMode mode) {
    // 串行保存连续点击，避免磁盘中的主题与界面状态顺序不一致。
    final operation = _pending.then((_) async {
      final saved = await ref
          .read(preferencesProvider)
          .setString(storageKey, mode.name);
      if (!saved) throw StateError('Unable to save theme');
      if (ref.mounted) state = mode;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }
}
