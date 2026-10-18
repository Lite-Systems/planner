import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/services/database_helper.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reopening loaded projects uses cached tasks without notifying every screen',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final directory = await Directory.systemTemp.createTemp(
        'planner_task_cache_',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      addTearDown(() async {
        await DatabaseHelper.instance.close();
        await directory.delete(recursive: true);
      });
      final db = DatabaseHelper.instance;
      for (final id in ['filled', 'empty']) {
        await db.insertProject(Project(id: id, name: id, description: ''));
      }
      await db.insertTask(
        ProjectTask(
          id: 'task',
          projectId: 'filled',
          name: 'Work',
          details: '',
          attachments: [],
          startDate: DateTime(2026, 10, 18),
          cost: 0,
        ),
      );
      final provider = ProjectProvider();
      addTearDown(provider.dispose);
      await provider.loadData();
      expect(provider.getTasks('filled'), hasLength(1));
      final cached = provider.getTasks('filled');
      var rebuilds = 0;
      provider.addListener(() => rebuilds++);
      for (var i = 0; i < 20; i++) {
        await provider.loadTasks(i.isEven ? 'filled' : 'empty');
      }
      expect(rebuilds, 0);
      expect(identical(provider.getTasks('filled'), cached), isTrue);
    },
  );
}
