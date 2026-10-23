import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Spark has no Cloud Storage. Device files stay local; other records still sync.
class LocalFilePolicy {
  LocalFilePolicy(this.db);
  final Database db;
  Future<Map<String, dynamic>> portable(
    String entity,
    Map<String, dynamic> data,
  ) async {
    final copy = Map<String, dynamic>.from(data);
    if (entity == 'projects') copy['imagePath'] = null;
    if (entity == 'tasks') copy['attachments'] = jsonEncode(<String>[]);
    return copy;
  }

  Future<Map<String, dynamic>> localize(
    String entity,
    Map<String, dynamic> data,
  ) async {
    final copy = Map<String, dynamic>.from(data);
    if (entity == 'projects' || entity == 'tasks') {
      final rows = await db.query(
        entity,
        where: 'id=?',
        whereArgs: [copy['id']],
      );
      if (entity == 'projects') {
        copy['imagePath'] = rows.isEmpty ? null : rows.first['imagePath'];
      }
      if (entity == 'tasks') {
        copy['attachments'] = rows.isEmpty ? '[]' : rows.first['attachments'];
      }
    }
    return copy;
  }
}
