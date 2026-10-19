import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// Exporta/importa o banco inteiro como JSON (cópia fiel das tabelas).
///
/// Importar SUBSTITUI todas as tarefas atuais — não há mescla.
class BackupService {
  static const _app = 'app_task';
  static const _format = 1;

  /// Ordem de inserção respeitando as FKs (pais antes dos filhos).
  static const tables = [
    'tasks',
    'task_recurrence_rules',
    'subtasks',
    'task_completions',
    'task_occurrences',
    'subtask_completions',
  ];

  /// Colunas que só existem em instalações migradas (sem uso desde v5).
  /// Ficam fora do backup para ele importar em instalação nova.
  static const _legacyColumns = {
    'tasks': {'archived'},
  };

  final DatabaseHelper _db;

  BackupService({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  Future<String> exportToJson() async {
    final db = await _db.database;
    final data = <String, dynamic>{};
    for (final table in tables) {
      data[table] = await db.query(table, columns: await _columns(db, table));
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': _app,
      'format': _format,
      'dbVersion': DatabaseHelper.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// Valida tudo antes de apagar qualquer coisa; grava em uma transação.
  /// Retorna o número de tarefas importadas.
  Future<int> importFromJson(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw BackupFormatException('Arquivo não é um JSON válido.');
    }

    if (decoded is! Map<String, dynamic> || decoded['app'] != _app) {
      throw BackupFormatException('Arquivo não é um backup do App Task.');
    }
    if (decoded['format'] != _format) {
      throw BackupFormatException('Formato de backup não suportado.');
    }
    if (decoded['dbVersion'] != DatabaseHelper.schemaVersion) {
      throw BackupFormatException(
        'Backup de outra versão do banco '
        '(${decoded['dbVersion']}, esperado ${DatabaseHelper.schemaVersion}).',
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw BackupFormatException('Backup sem dados.');
    }

    final db = await _db.database;
    final rowsByTable = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      final rows = data[table];
      if (rows is! List) {
        throw BackupFormatException('Tabela "$table" ausente no backup.');
      }
      final columns = (await _columns(db, table)).toSet();
      rowsByTable[table] = rows.map((row) {
        if (row is! Map<String, dynamic>) {
          throw BackupFormatException('Linha inválida em "$table".');
        }
        final legacy = _legacyColumns[table] ?? const <String>{};
        final unknown = row.keys.where(
          (k) => !columns.contains(k) && !legacy.contains(k),
        );
        if (unknown.isNotEmpty) {
          throw BackupFormatException(
            'Coluna desconhecida em "$table": ${unknown.join(', ')}.',
          );
        }
        return Map<String, Object?>.from(row)
          ..removeWhere((k, _) => !columns.contains(k));
      }).toList();
    }

    try {
      await db.transaction((txn) async {
        // CASCADE limpa as tabelas filhas.
        await txn.delete('tasks');
        for (final table in tables) {
          for (final row in rowsByTable[table]!) {
            await txn.insert(table, row);
          }
        }
      });
    } on DatabaseException catch (e) {
      throw BackupFormatException('Backup inconsistente: $e');
    }

    return rowsByTable['tasks']!.length;
  }

  Future<List<String>> _columns(Database db, String table) async {
    final legacy = _legacyColumns[table] ?? const <String>{};
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info
        .map((r) => r['name'] as String)
        .where((c) => !legacy.contains(c))
        .toList();
  }
}
