import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  group('Migration → v6', () {
    late Directory dir;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('app_task_migration_v6_');
      dbHelper = DatabaseHelper.test(await createV2DatabaseFixture(dir));
    });

    tearDown(() async {
      await dbHelper.closeForTest();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('cria colunas de intervalo e preserva dados', () async {
      final db = await dbHelper.database;
      expect(
        Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')),
        6,
      );
      for (final table in [
        'tasks',
        'task_recurrence_rules',
        'task_occurrences',
      ]) {
        final cols = (await db.rawQuery('PRAGMA table_info($table)'))
            .map((r) => r['name'])
            .toSet();
        expect(cols, containsAll(['end_time', 'break_start', 'break_end']));
      }

      final service = TaskService(db: dbHelper);
      final treino =
          (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino v2'))!;
      expect(treino.effectiveTime, '15:00');
      expect(treino.effectiveEndTime, isNull);
      expect(treino.effectiveRange.hasEnd, isFalse);
    });
  });
}
