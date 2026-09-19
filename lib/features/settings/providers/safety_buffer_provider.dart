import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import 'theme_provider.dart';

final safetyBufferProvider = NotifierProvider<SafetyBufferController, int>(
  SafetyBufferController.new,
);

class SafetyBufferController extends Notifier<int> {
  static const storageKey = 'safety_buffer_cents';

  @override
  int build() => ref.watch(preferencesProvider).getInt(storageKey) ?? 0;

  Future<void> setValue(int cents) async {
    if (cents < 0 || cents > Money.maxCents) {
      throw ArgumentError.value(cents, 'cents');
    }
    final saved = await ref.read(preferencesProvider).setInt(storageKey, cents);
    if (!saved) throw StateError('Unable to save safety buffer');
    state = cents;
  }
}
