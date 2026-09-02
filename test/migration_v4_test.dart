import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  group('Migration v3 → v4', () {
    late Directory dir;
    late String dbPath;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('app_task_migration_v4_');
      dbPath = '${dir.path}/migration_v3.db';

      final db = await openDatabase(
        dbPath,
        version: 3,
        onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, version) async {
          await d.execute('''
            CREATE TABLE tasks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              description TEXT,
              due_date TEXT,
              completed INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              is_recurring INTEGER DEFAULT 0,
              recurring_days TEXT,
              time TEXT,
              archived INTEGER DEFAULT 0
            )
          ''');
          await d.insert('tasks', {
            'title': 'Treino v3',
            'created_at': '2026-01-01T00:00:00.000',
            'is_recurring': 1,
            'recurring_days': '1,3',
            'time': '15:00',
          });
        },
      );
      await db.close();

      dbHelper = DatabaseHelper.test(dbPath);
    });

    tearDown(() async {
      await dbHelper.closeForTest();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('cria regras para recorrentes existentes', () async {
      final db = await dbHelper.database;
      final rules = await db.query('task_recurrence_rules');
      expect(rules.length, 1);
      expect(rules.first['recurring_days'], '1,3');
      expect(rules.first['effective_from'], kLegacyRuleEffectiveFrom);
    });
  });
}
