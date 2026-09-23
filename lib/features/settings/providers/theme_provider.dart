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
  late ThemeMode _savedMode;

  @override
  ThemeMode build() {
    _savedMode = switch (ref.watch(preferencesProvider).getString(storageKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return _savedMode;
  }

  Future<void> setMode(ThemeMode mode) {
    // 先更新界面，避免等待本地存储时让选项看起来没有响应。
    state = mode;
    // 串行保存连续点击，避免磁盘中的主题与界面状态顺序不一致。
    final operation = _pending.then((_) async {
      try {
        final saved = await ref
            .read(preferencesProvider)
            .setString(storageKey, mode.name);
        if (!saved) throw StateError('Unable to save theme');
        _savedMode = mode;
      } catch (_) {
        if (ref.mounted && state == mode) state = _savedMode;
        rethrow;
      }
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }
}
