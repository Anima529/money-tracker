import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/backup/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase source;
  late SharedPreferences prefs;
  late BackupService service;
  final now = DateTime(2026, 9, 23, 10);
  const scheduleUuid = '00000000-0000-4000-8000-000000000002';
  const transactionUuid = '00000000-0000-4000-8000-000000000003';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'safety_buffer_cents': 5000,
      'transaction_recent_account_id': 1,
    });
    prefs = await SharedPreferences.getInstance();
    source = AppDatabase.forTesting(NativeDatabase.memory());
    service = BackupService(source, prefs);
    // The default account is created when the database opens.
    await source.select(source.accounts).get();
    await source
        .into(source.schedules)
        .insert(
          SchedulesCompanion.insert(
            uuid: scheduleUuid,
            title: '房租',
            type: 'expense',
            amount: 200000,
            category: 'housing',
            accountId: 1,
            frequency: 'monthly',
            startDate: DateTime(2026, 9, 1),
            nextDate: DateTime(2026, 10, 1),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await source
        .into(source.transactions)
        .insert(
          TransactionsCompanion.insert(
            uuid: transactionUuid,
            type: 'expense',
            amount: 2580,
            category: 'food',
            accountId: 1,
            status: 'confirmed',
            source: 'schedule',
            scheduleId: const Value(1),
            scheduledFor: Value(DateTime(2026, 9, 1)),
            transactionDate: DateTime(2026, 9, 1),
            confirmedAt: Value(now),
            deletedAt: Value(now),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await source
        .into(source.scheduleSkips)
        .insert(
          ScheduleSkipsCompanion.insert(
            scheduleId: 1,
            scheduledFor: DateTime(2026, 10, 1),
            createdAt: now,
          ),
        );
    await source
        .into(source.merchantRules)
        .insert(
          MerchantRulesCompanion.insert(
            pattern: '瑞幸',
            category: 'food',
            accountId: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async => source.close());

  test('round trip preserves linked rows, trash, preferences and merge is idempotent', () async {
    final bytes = await service.export();
    final document = service.inspect(bytes);
    expect(document.preview.counts['transactions'], 1);
    final target = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await target.select(target.accounts).get();
      final targetService = BackupService(target, prefs);
      await targetService.restore(document, RestoreMode.replace);
      await targetService.restore(document, RestoreMode.merge);
      expect(await target.select(target.accounts).get(), hasLength(1));
      expect(await target.select(target.schedules).get(), hasLength(1));
      expect(await target.select(target.scheduleSkips).get(), hasLength(1));
      expect(await target.select(target.merchantRules).get(), hasLength(1));
      final transaction =
          (await target.select(target.transactions).get()).single;
      expect(transaction.uuid, transactionUuid);
      expect(transaction.deletedAt, isNotNull);
      expect(
        transaction.scheduleId,
        (await target.select(target.schedules).get()).single.id,
      );
      expect(prefs.getInt('safety_buffer_cents'), 5000);
      expect(prefs.getString('theme_mode'), 'dark');
    } finally {
      await target.close();
    }
  });

  test('unsupported version and corrupt zip fail before any write', () async {
    final bytes = await service.export();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final version in [0, 99]) {
      final modified = Archive();
      for (final file in archive) {
        modified.addFile(
          file.name == 'manifest.json'
              ? ArchiveFile.string(
                  'manifest.json',
                  jsonEncode({
                    'format': 'money-tracker',
                    'version': version,
                    'createdAt': now.toIso8601String(),
                    'counts': {},
                  }),
                )
              : ArchiveFile.bytes(file.name, file.readBytes()!),
        );
      }
      expect(
        () =>
            service.inspect(Uint8List.fromList(ZipEncoder().encode(modified))),
        throwsA(isA<BackupException>()),
      );
    }
    expect(
      () => service.inspect(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<BackupException>()),
    );
    expect(await source.select(source.transactions).get(), hasLength(1));
  });

  test('a failed merge rolls back all earlier inserted rows', () async {
    final document = service.inspect(await service.export());
    final target = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await target.select(target.accounts).get();
      // A different UUID holding the same source fingerprint forces a unique conflict.
      await target
          .into(target.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: '00000000-0000-4000-8000-000000000099',
              type: 'expense',
              amount: 100,
              category: 'food',
              accountId: 1,
              status: 'confirmed',
              source: 'manual',
              sourceFingerprint: const Value('same'),
              transactionDate: now,
              confirmedAt: Value(now),
              createdAt: now,
              updatedAt: now,
            ),
          );
      document.data['transactions']!.single['sourceFingerprint'] = 'same';
      await expectLater(
        BackupService(target, prefs).restore(document, RestoreMode.merge),
        throwsA(anything),
      );
      expect(await target.select(target.schedules).get(), isEmpty);
      expect(await target.select(target.transactions).get(), hasLength(1));
    } finally {
      await target.close();
    }
  });
}
