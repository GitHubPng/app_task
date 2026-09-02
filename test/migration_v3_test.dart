import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  group('Migration v2 → v3', () {
    late Directory dir;
    late String v2Path;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('app_task_migration_');
      v2Path = await createV2DatabaseFixture(dir);
      dbHelper = DatabaseHelper.test(v2Path);
    });

    tearDown(() async {
      await dbHelper.closeForTest();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    Future<Database> openMigrated() async {
      return dbHelper.database;
    }

    test('preserva dados e cria tabelas v3', () async {
      final db = await openMigrated();

      final tasks = await db.query('tasks');
      expect(tasks.length, 3);

      final recurring = tasks.firstWhere((t) => t['title'] == 'Treino v2');
      expect(recurring['recurring_days'], '1,3');
      expect(recurring['is_recurring'], 1);

      final oneOff = tasks.firstWhere((t) => t['title'] == 'Avulsa v2');
      expect(oneOff['due_date'], '2026-09-03');

      final archived = tasks.firstWhere((t) => t['title'] == 'Arquivada v2');
      expect(archived['archived'], 1);

      final subtasks = await db.query('subtasks');
      expect(subtasks.length, 2);

      final recurringSub = subtasks.firstWhere((s) => s['title'] == 'Supino');
      expect(recurringSub['completed'], 0);

      final oneOffSub =
          subtasks.firstWhere((s) => s['title'] == 'Etapa avulsa');
      expect(oneOffSub['completed'], 1);

      final completions = await db.query('task_completions');
      expect(completions.length, 1);
      expect(completions.first['completion_date'], '2026-08-31');

      expect(await _tableExists(db, 'task_occurrences'), isTrue);
      expect(await _tableExists(db, 'subtask_completions'), isTrue);

      final occurrences = await db.query('task_occurrences');
      expect(occurrences, isEmpty);
    });

    test('user_version é 3 após abertura', () async {
      final db = await openMigrated();
      final version = Sqflite.firstIntValue(
        await db.rawQuery('PRAGMA user_version'),
      );
      expect(version, 3);
    });
  });
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    [table],
  );
  return rows.isNotEmpty;
}
