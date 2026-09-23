import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../settings/providers/safety_buffer_provider.dart';
import '../settings/providers/theme_provider.dart';

enum RestoreMode { replace, merge }

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupPreview {
  const BackupPreview({required this.createdAt, required this.counts});
  final DateTime createdAt;
  final Map<String, int> counts;
}

class BackupDocument {
  const BackupDocument(this.preview, this.data);
  final BackupPreview preview;
  final Map<String, List<Map<String, dynamic>>> data;
}

/// Version 1 stores stable UUID references instead of device-local row IDs.
class BackupService {
  BackupService(this.database, this.preferences);

  final AppDatabase database;
  final SharedPreferences preferences;

  static const format = 'money-tracker';
  static const version = 1;
  static const _sections = [
    'accounts',
    'schedules',
    'transactions',
    'schedule_skips',
    'merchant_rules',
    'preferences',
  ];

  Future<Uint8List> export() async {
    final data = await database.transaction(() async {
      final accounts = await database.select(database.accounts).get();
      final schedules = await database.select(database.schedules).get();
      final transactions = await database.select(database.transactions).get();
      final skips = await database.select(database.scheduleSkips).get();
      final rules = await database.select(database.merchantRules).get();
      final accountUuids = {for (final row in accounts) row.id: row.uuid};
      final scheduleUuids = {for (final row in schedules) row.id: row.uuid};

      Map<String, dynamic> withAccountRefs(Map<String, dynamic> row) {
        row.remove('id');
        row['accountUuid'] = accountUuids[row.remove('accountId')];
        final transferId = row.remove('transferAccountId') as int?;
        row['transferAccountUuid'] = transferId == null
            ? null
            : accountUuids[transferId];
        return row;
      }

      return <String, List<Map<String, dynamic>>>{
        'accounts': [for (final row in accounts) row.toJson()..remove('id')],
        'schedules': [
          for (final row in schedules) withAccountRefs(row.toJson()),
        ],
        'transactions': [
          for (final row in transactions)
            withAccountRefs(row.toJson())
              ..['scheduleUuid'] = row.scheduleId == null
                  ? null
                  : scheduleUuids[row.scheduleId]
              ..remove('scheduleId'),
        ],
        'schedule_skips': [
          for (final row in skips)
            <String, dynamic>{
              'scheduleUuid': scheduleUuids[row.scheduleId],
              'scheduledFor': row.toJson()['scheduledFor'],
              'createdAt': row.toJson()['createdAt'],
            },
        ],
        'merchant_rules': [
          for (final row in rules)
            row.toJson()
              ..remove('id')
              ..['accountUuid'] = row.accountId == null
                  ? null
                  : accountUuids[row.accountId]
              ..remove('accountId'),
        ],
        'preferences': [
          {
            'themeMode':
                preferences.getString(ThemeModeController.storageKey) ??
                'system',
            'safetyBufferCents':
                preferences.getInt(SafetyBufferController.storageKey) ?? 0,
            'recentAccountUuid':
                accountUuids[preferences.getInt(
                  'transaction_recent_account_id',
                )],
            'recentExpenseCategory': preferences.getString(
              'transaction_recent_expense_category',
            ),
            'recentIncomeCategory': preferences.getString(
              'transaction_recent_income_category',
            ),
          },
        ],
      };
    });
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final counts = {
      for (final section in _sections) section: data[section]!.length,
    };
    final archive = Archive();
    archive.addFile(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'format': format,
          'version': version,
          'createdAt': createdAt,
          'counts': counts,
        }),
      ),
    );
    for (final section in _sections) {
      archive.addFile(
        ArchiveFile.string('$section.json', jsonEncode(data[section])),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  BackupDocument inspect(Uint8List bytes) {
    if (bytes.length > 50 * 1024 * 1024) {
      throw const BackupException('备份文件超过 50 MB');
    }
    try {
      final zip = ZipDecoder().decodeBytes(bytes);
      final files = <String, ArchiveFile>{};
      var totalSize = 0;
      for (final file in zip) {
        totalSize += file.size;
        if (files.containsKey(file.name) || totalSize > 50 * 1024 * 1024) {
          throw const BackupException('备份包含重复或过大的文件');
        }
        files[file.name] = file;
      }
      dynamic readJson(String name) {
        final file = files[name];
        if (file == null) throw BackupException('缺少 $name');
        final content = file.readBytes();
        if (content == null) throw BackupException('$name 无法读取');
        return jsonDecode(utf8.decode(content));
      }

      final manifest = _object(readJson('manifest.json'));
      if (manifest['format'] != format) throw const BackupException('不是简记备份文件');
      if (manifest['version'] != version) {
        throw BackupException('不支持的备份版本：${manifest['version']}');
      }
      final createdAt = DateTime.parse(manifest['createdAt'] as String);
      final listedCounts = _object(manifest['counts']);
      final data = <String, List<Map<String, dynamic>>>{};
      final counts = <String, int>{};
      for (final section in _sections) {
        final rows = readJson('$section.json');
        if (rows is! List) throw BackupException('$section.json 内容无效');
        data[section] = rows.map(_object).toList();
        counts[section] = rows.length;
        if (listedCounts[section] != rows.length) {
          throw BackupException('$section 数量与清单不符');
        }
      }
      _validate(data);
      return BackupDocument(
        BackupPreview(createdAt: createdAt, counts: counts),
        data,
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('备份文件损坏或格式无效');
    }
  }

  static Map<String, dynamic> _object(dynamic value) {
    if (value is! Map<String, dynamic>) throw const BackupException('备份数据格式无效');
    return value;
  }

  static void _validate(Map<String, List<Map<String, dynamic>>> data) {
    final accounts = <String>{};
    final schedules = <String>{};
    final transactions = <String>{};
    final patterns = <String>{};
    for (final row in data['accounts']!) {
      final uuid = row['uuid'];
      if (uuid is! String || !accounts.add(uuid)) {
        throw const BackupException('账户 UUID 无效或重复');
      }
      AccountRow.fromJson({...row, 'id': 0});
    }
    if (accounts.isEmpty) throw const BackupException('备份中没有账户');
    for (final row in data['schedules']!) {
      final uuid = row['uuid'];
      if (uuid is! String || !schedules.add(uuid)) {
        throw const BackupException('计划 UUID 无效或重复');
      }
      _checkAccountRefs(row, accounts);
      ScheduleRow.fromJson({
        ...row,
        'id': 0,
        'accountId': 1,
        'transferAccountId': row['transferAccountUuid'] == null ? null : 2,
      });
    }
    for (final row in data['transactions']!) {
      final uuid = row['uuid'];
      if (uuid is! String || !transactions.add(uuid)) {
        throw const BackupException('账单 UUID 无效或重复');
      }
      _checkAccountRefs(row, accounts);
      final scheduleUuid = row['scheduleUuid'];
      if (scheduleUuid != null && !schedules.contains(scheduleUuid)) {
        throw const BackupException('账单引用了缺失的计划');
      }
      TransactionRow.fromJson({
        ...row,
        'id': 0,
        'accountId': 1,
        'transferAccountId': row['transferAccountUuid'] == null ? null : 2,
        'scheduleId': scheduleUuid == null ? null : 1,
      });
    }
    final skipKeys = <String>{};
    for (final row in data['schedule_skips']!) {
      if (!schedules.contains(row['scheduleUuid'])) {
        throw const BackupException('跳过记录引用了缺失的计划');
      }
      if (!skipKeys.add('${row['scheduleUuid']}/${row['scheduledFor']}')) {
        throw const BackupException('重复的跳过记录');
      }
      ScheduleSkipRow.fromJson({...row, 'id': 0, 'scheduleId': 1});
    }
    for (final row in data['merchant_rules']!) {
      final pattern = row['pattern'];
      if (pattern is! String || !patterns.add(pattern)) {
        throw const BackupException('商户规则重复或无效');
      }
      final accountUuid = row['accountUuid'];
      if (accountUuid != null && !accounts.contains(accountUuid)) {
        throw const BackupException('商户规则引用了缺失的账户');
      }
      MerchantRuleRow.fromJson({
        ...row,
        'id': 0,
        'accountId': accountUuid == null ? null : 1,
      });
    }
    if (data['preferences']!.length != 1) {
      throw const BackupException('偏好设置格式无效');
    }
    final prefs = data['preferences']!.single;
    if (!['system', 'light', 'dark'].contains(prefs['themeMode']) ||
        prefs['safetyBufferCents'] is! int ||
        (prefs['safetyBufferCents'] as int) < 0 ||
        (prefs['safetyBufferCents'] as int) > 999999999999 ||
        (prefs['recentAccountUuid'] != null &&
            !accounts.contains(prefs['recentAccountUuid'])) ||
        (prefs['recentExpenseCategory'] != null &&
            prefs['recentExpenseCategory'] is! String) ||
        (prefs['recentIncomeCategory'] != null &&
            prefs['recentIncomeCategory'] is! String)) {
      throw const BackupException('偏好设置格式无效');
    }
  }

  static void _checkAccountRefs(
    Map<String, dynamic> row,
    Set<String> accounts,
  ) {
    if (!accounts.contains(row['accountUuid']) ||
        (row['transferAccountUuid'] != null &&
            !accounts.contains(row['transferAccountUuid']))) {
      throw const BackupException('记录引用了缺失的账户');
    }
  }

  /// False means rows were restored, but some device preferences did not save.
  Future<bool> restore(BackupDocument backup, RestoreMode mode) async {
    // Re-check before entering the write transaction; callers may construct a document.
    _validate(backup.data);
    final data = backup.data;
    final accountIds = <String, int>{};
    await database.transaction(() async {
      if (mode == RestoreMode.replace) {
        await database.delete(database.transactions).go();
        await database.delete(database.scheduleSkips).go();
        await database.delete(database.merchantRules).go();
        await database.delete(database.schedules).go();
        await database.delete(database.accounts).go();
      }
      for (final row in await database.select(database.accounts).get()) {
        accountIds[row.uuid] = row.id;
      }
      for (final json in data['accounts']!) {
        final row = AccountRow.fromJson({...json, 'id': 0});
        accountIds[row.uuid] ??= await database
            .into(database.accounts)
            .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
      }
      final scheduleIds = <String, int>{};
      for (final row in await database.select(database.schedules).get()) {
        scheduleIds[row.uuid] = row.id;
      }
      for (final json in data['schedules']!) {
        final row = ScheduleRow.fromJson({
          ...json,
          'id': 0,
          'accountId': accountIds[json['accountUuid']],
          'transferAccountId': accountIds[json['transferAccountUuid']],
        });
        scheduleIds[row.uuid] ??= await database
            .into(database.schedules)
            .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
      }
      final existingTransactionUuids = {
        for (final row in await database.select(database.transactions).get())
          row.uuid,
      };
      for (final json in data['transactions']!) {
        if (!existingTransactionUuids.add(json['uuid'] as String)) continue;
        final row = TransactionRow.fromJson({
          ...json,
          'id': 0,
          'accountId': accountIds[json['accountUuid']],
          'transferAccountId': accountIds[json['transferAccountUuid']],
          'scheduleId': scheduleIds[json['scheduleUuid']],
        });
        await database
            .into(database.transactions)
            .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
      }
      final existingSkips = {
        for (final row in await database.select(database.scheduleSkips).get())
          '${scheduleIds.entries.singleWhere((entry) => entry.value == row.scheduleId).key}/${row.toJson()['scheduledFor']}',
      };
      for (final json in data['schedule_skips']!) {
        final key = '${json['scheduleUuid']}/${json['scheduledFor']}';
        if (!existingSkips.add(key)) continue;
        final row = ScheduleSkipRow.fromJson({
          ...json,
          'id': 0,
          'scheduleId': scheduleIds[json['scheduleUuid']],
        });
        await database
            .into(database.scheduleSkips)
            .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
      }
      final existingPatterns = {
        for (final row in await database.select(database.merchantRules).get())
          row.pattern,
      };
      for (final json in data['merchant_rules']!) {
        if (!existingPatterns.add(json['pattern'] as String)) continue;
        final row = MerchantRuleRow.fromJson({
          ...json,
          'id': 0,
          'accountId': accountIds[json['accountUuid']],
        });
        await database
            .into(database.merchantRules)
            .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
      }
    });
    if (mode == RestoreMode.replace) {
      final prefs = data['preferences']!.single;
      try {
        var saved = await preferences.setString(
          ThemeModeController.storageKey,
          prefs['themeMode'] as String,
        );
        saved =
            await preferences.setInt(
              SafetyBufferController.storageKey,
              prefs['safetyBufferCents'] as int,
            ) &&
            saved;
        final recentId = accountIds[prefs['recentAccountUuid']];
        if (recentId == null) {
          saved =
              await preferences.remove('transaction_recent_account_id') &&
              saved;
        } else {
          saved =
              await preferences.setInt(
                'transaction_recent_account_id',
                recentId,
              ) &&
              saved;
        }
        for (final pair in [
          (
            'transaction_recent_expense_category',
            prefs['recentExpenseCategory'],
          ),
          ('transaction_recent_income_category', prefs['recentIncomeCategory']),
        ]) {
          if (pair.$2 == null) {
            saved = await preferences.remove(pair.$1) && saved;
          } else {
            saved =
                await preferences.setString(pair.$1, pair.$2 as String) &&
                saved;
          }
        }
        return saved;
      } catch (_) {
        return false;
      }
    }
    return true;
  }
}
