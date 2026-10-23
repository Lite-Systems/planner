import 'dart:developer';
import 'dart:convert';
import 'dart:io';

import 'package:planner/models/expense.dart';
import 'package:planner/models/expense_category.dart';
import 'package:planner/models/income.dart';
import 'package:planner/models/income_category.dart';
import 'package:planner/models/payment_method.dart';
import 'package:planner/models/project_member.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../sync/sync_store.dart';
import '../../models/project.dart';
import '../../models/project_task.dart';
import '../../models/sticky_note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Future<Database>? _databaseOpening;
  static const dbFileName = 'planner.db';
  static const legacyDbFileName = 'masrofy.db';

  DatabaseHelper._init();

  String? _accountId;
  String? get accountId => _accountId;
  Future<String> get activePath async {
    final directory = await getDatabasesPath();
    return _accountId == null
        ? resolveDbPath(directory)
        : join(directory, 'accounts', _accountId!, dbFileName);
  }

  Future<void> switchAccount(String? id) async {
    if (id != null && !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid account identifier');
    }
    if (_accountId == id) return;
    await close();
    _accountId = id;
    await database;
  }

  Future<void> setAccountPreference(String key, Object value) async {
    final db = await database;
    await db.insert('account_settings', {
      'id': key,
      'value': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> accountPreferences() async {
    final db = await database;
    return {
      for (final row in await db.query('account_settings'))
        row['id']! as String: jsonDecode(row['value']! as String),
    };
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _databaseOpening ??= _initDB();
    _database = await _databaseOpening!;
    _databaseOpening = null;
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = await activePath;
    await Directory(dirname(path)).create(recursive: true);

    return await openDatabase(
      path,
      version: 24,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: (db) => SyncStore.install(db, enabled: _accountId != null),
    );
  }

  static Future<String> resolveDbPath(String directory) async {
    final path = join(directory, dbFileName);
    if (await File(path).exists()) return path;
    final legacy = File(join(directory, legacyDbFileName));
    if (await legacy.exists()) {
      await legacy.copy(path);
      for (final suffix in ['-wal', '-shm']) {
        final extra = File('${legacy.path}$suffix');
        if (await extra.exists()) {
          await extra.copy('$path$suffix');
        }
      }
    }
    return path;
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
CREATE TABLE payment_methods (
  id $idType,
  name $textType,
  color $integerType,
  icon $integerType,
  type $textNullable,
  cardNumber $textNullable,
  startingBalance REAL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE projects (
  id $idType,
  name $textType,
  description $textNullable,
  endDate $textNullable,
  status $textType,
  imagePath $textNullable,
  customer $textNullable,
  coverType TEXT DEFAULT 'image',
  icon INTEGER
)
''');

    await db.execute('''
CREATE TABLE tasks (
  id $idType,
  projectId $textType,
  name $textType,
  details $textNullable,
  attachments $textNullable,
  startDate $textType,
  endDate $textNullable,
  cost $realType,
  currency $textType,
  isCompleted $integerType,
  status $textType,
  type $textType,
  subTasks $textNullable,
  isPaid INTEGER DEFAULT 0,
  paymentMethodId TEXT,
  timeSpentInSeconds INTEGER DEFAULT 0,
  isTimerRunning INTEGER DEFAULT 0,
  lastStartTime TEXT,
  timerStartAt TEXT,
  timerEndAt TEXT,
  estimatedTime REAL DEFAULT 0,
  hourlyRate REAL DEFAULT 0,
  isArchived INTEGER DEFAULT 0,
  FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE,
  FOREIGN KEY (paymentMethodId) REFERENCES payment_methods (id)
)
''');

    await db.execute('''
CREATE TABLE project_members (
  id $idType,
  projectId $textType,
  name $textType,
  phone $textNullable,
  email $textNullable,
  color $integerType,
  FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE task_assignees (
  taskId TEXT NOT NULL,
  memberId TEXT NOT NULL,
  PRIMARY KEY (taskId, memberId),
  FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE,
  FOREIGN KEY (memberId) REFERENCES project_members (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE expense_categories (
  id $idType,
  name $textType,
  color $integerType,
  icon $integerType,
  isDefault INTEGER DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE expenses (
  id $idType,
  title $textType,
  amount $realType,
  date $textType,
  categoryId $textType,
  paymentMethodId $textNullable,
  note $textNullable,
  taskId $textNullable,
  currency $textType,
  FOREIGN KEY (categoryId) REFERENCES expense_categories (id),
  FOREIGN KEY (paymentMethodId) REFERENCES payment_methods (id),
  FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE SET NULL
)
''');

    await db.execute('''
CREATE TABLE income_categories (
  id $idType,
  name $textType,
  color $integerType,
  icon $integerType,
  isDefault INTEGER DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE incomes (
  id $idType,
  title TEXT,
  amount $realType,
  date $textType,
  categoryId $textType,
  note $textNullable,
  paymentMethodId $textNullable,
  taskId $textNullable,
  currency TEXT,
  FOREIGN KEY (categoryId) REFERENCES income_categories (id),
  FOREIGN KEY (paymentMethodId) REFERENCES payment_methods (id),
  FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE SET NULL
)
''');

    await db.execute('''
CREATE TABLE sticky_notes (
  id $idType,
  content $textType,
  colorIndex INTEGER DEFAULT 0,
  createdAt $textType,
  updatedAt $textType
)
''');

    await _createIndexes(db);
  }

  /// Indexes backing the foreign-key lookups and the common filter/sort
  /// columns. Created both on fresh installs ([_createDB]) and on upgrade to
  /// v22 ([_onUpgrade]) — `IF NOT EXISTS` keeps both paths idempotent.
  Future<void> _createIndexes(Database db) async {
    const statements = <String>[
      'CREATE INDEX IF NOT EXISTS idx_tasks_projectId ON tasks(projectId)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_paymentMethodId ON tasks(paymentMethodId)',
      'CREATE INDEX IF NOT EXISTS idx_project_members_projectId ON project_members(projectId)',
      'CREATE INDEX IF NOT EXISTS idx_task_assignees_memberId ON task_assignees(memberId)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_categoryId ON expenses(categoryId)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_paymentMethodId ON expenses(paymentMethodId)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_taskId ON expenses(taskId)',
      'CREATE INDEX IF NOT EXISTS idx_incomes_date ON incomes(date)',
      'CREATE INDEX IF NOT EXISTS idx_incomes_categoryId ON incomes(categoryId)',
      'CREATE INDEX IF NOT EXISTS idx_incomes_paymentMethodId ON incomes(paymentMethodId)',
      'CREATE INDEX IF NOT EXISTS idx_incomes_taskId ON incomes(taskId)',
    ];
    for (final sql in statements) {
      await db.execute(sql);
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const textNullable = 'TEXT';

    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE expenses ADD COLUMN paymentMethodId TEXT',
        );
        await db.execute('''
CREATE TABLE payment_methods (
  id $idType,
  name $textType,
  color $integerType,
  icon $integerType
)
''');
      } catch (e) {
        log('Migration Error v2: $e');
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute('''
CREATE TABLE income_categories (
  id $idType,
  name $textType,
  color $integerType,
  icon $integerType
)
''');

        await db.execute('''
CREATE TABLE incomes (
  id $idType,
  amount $realType,
  date $textType,
  categoryId $textType,
  note $textNullable,
  FOREIGN KEY (categoryId) REFERENCES income_categories (id)
)
''');
      } catch (e) {
        log('Migration Error v3: $e');
      }
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE payment_methods ADD COLUMN type TEXT');
        await db.execute(
          'ALTER TABLE payment_methods ADD COLUMN cardNumber TEXT',
        );
      } catch (e) {
        log('Migration Error v4: $e');
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute('''
CREATE TABLE projects (
  id $idType,
  name $textType,
  description $textNullable,
  endDate $textNullable,
  status $textType
)
''');

        await db.execute('''
CREATE TABLE tasks (
  id $idType,
  projectId $textType,
  name $textType,
  details $textNullable,
  attachments $textNullable,
  startDate $textType,
  endDate $textNullable,
  cost $realType,
  currency $textType,
  isCompleted $integerType,
  status $textType,
  FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
)
''');
      } catch (e) {
        log('Migration Error v5: $e');
      }
    }

    if (oldVersion < 12) {
      try {
        // Ensure projects and tasks table exist even if v5 migration was skipped or failed partially
        await db.execute('''
          CREATE TABLE IF NOT EXISTS projects (
            id $idType,
            name $textType,
            description $textNullable,
            endDate $textNullable,
            status $textType
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS tasks (
            id $idType,
            projectId $textType,
            name $textType,
            details $textNullable,
            attachments $textNullable,
            startDate $textType,
            endDate $textNullable,
            cost $realType,
            currency $textType,
            isCompleted $integerType,
            status $textType,
            FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
          )
        ''');

        // Now add the new columns for v12
        await db.execute(
          "ALTER TABLE tasks ADD COLUMN isPaid INTEGER DEFAULT 0",
        );
        await db.execute("ALTER TABLE tasks ADD COLUMN paymentMethodId TEXT");
      } catch (e) {
        log('Migration Error v12: $e');
      }
    }

    if (oldVersion < 13) {
      try {
        await db.execute(
          "ALTER TABLE tasks ADD COLUMN timeSpentInSeconds INTEGER DEFAULT 0",
        );
        await db.execute(
          "ALTER TABLE tasks ADD COLUMN isTimerRunning INTEGER DEFAULT 0",
        );
        await db.execute("ALTER TABLE tasks ADD COLUMN lastStartTime TEXT");
      } catch (e) {
        log('Migration Error v13: $e');
      }
    }

    if (oldVersion < 14) {
      try {
        await db.execute(
          "ALTER TABLE tasks ADD COLUMN estimatedTime REAL DEFAULT 0",
        );
      } catch (e) {
        log('Migration Error v14: $e');
      }
    }

    if (oldVersion < 15) {
      try {
        await db.execute(
          "ALTER TABLE tasks ADD COLUMN hourlyRate REAL DEFAULT 0",
        );
      } catch (e) {
        log('Migration Error v15: $e');
      }
    }

    if (oldVersion < 16) {
      try {
        await db.execute(
          "ALTER TABLE tasks ADD COLUMN isArchived INTEGER DEFAULT 0",
        );
      } catch (e) {
        log('Migration Error v16: $e');
      }
    }

    if (oldVersion < 17) {
      try {
        await db.execute("ALTER TABLE tasks ADD COLUMN timerStartAt TEXT");
        await db.execute("ALTER TABLE tasks ADD COLUMN timerEndAt TEXT");
      } catch (e) {
        log('Migration Error v17: $e');
      }
    }

    if (oldVersion < 18) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expense_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            icon INTEGER NOT NULL,
            isDefault INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expenses (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            categoryId TEXT NOT NULL,
            paymentMethodId TEXT,
            note TEXT,
            taskId TEXT,
            currency TEXT NOT NULL
          )
        ''');
      } catch (e) {
        log('Migration Error v18: $e');
      }
    }

    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE projects ADD COLUMN imagePath TEXT');
      } catch (e) {
        log('Migration Error v19 imagePath: $e');
      }
      try {
        await db.execute(
          "UPDATE tasks SET status = 'toDo' WHERE status = 'todo'",
        );
      } catch (e) {
        log('Migration Error v19 status: $e');
      }
      try {
        await db.execute(
          'ALTER TABLE payment_methods ADD COLUMN startingBalance REAL DEFAULT 0',
        );
      } catch (e) {
        log('Migration Error v19 startingBalance: $e');
      }
      try {
        await db.execute(
          "ALTER TABLE incomes ADD COLUMN title TEXT DEFAULT ''",
        );
        await db.execute('ALTER TABLE incomes ADD COLUMN paymentMethodId TEXT');
        await db.execute('ALTER TABLE incomes ADD COLUMN taskId TEXT');
        await db.execute(
          "ALTER TABLE incomes ADD COLUMN currency TEXT DEFAULT 'EGP'",
        );
        await db.execute(
          'ALTER TABLE income_categories ADD COLUMN isDefault INTEGER DEFAULT 0',
        );
      } catch (e) {
        log('Migration Error v19 income columns: $e');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS income_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            icon INTEGER NOT NULL,
            isDefault INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS incomes (
            id TEXT PRIMARY KEY,
            title TEXT,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            categoryId TEXT NOT NULL,
            note TEXT,
            paymentMethodId TEXT,
            taskId TEXT,
            currency TEXT
          )
        ''');
      } catch (e) {
        log('Migration Error v19 income tables: $e');
      }
    }

    if (oldVersion < 20) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS project_members (
            id TEXT PRIMARY KEY,
            projectId TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            color INTEGER NOT NULL,
            FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS task_assignees (
            taskId TEXT NOT NULL,
            memberId TEXT NOT NULL,
            PRIMARY KEY (taskId, memberId),
            FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE,
            FOREIGN KEY (memberId) REFERENCES project_members (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        log('Migration Error v20 members: $e');
      }
    }

    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE projects ADD COLUMN customer TEXT');
        await db.execute(
          "ALTER TABLE projects ADD COLUMN coverType TEXT DEFAULT 'image'",
        );
        await db.execute('ALTER TABLE projects ADD COLUMN icon INTEGER');
      } catch (e) {
        log('Migration Error v21 project cover/customer: $e');
      }
    }

    if (oldVersion < 22) {
      try {
        await _createIndexes(db);
      } catch (e) {
        log('Migration Error v22 indexes: $e');
      }
    }

    if (oldVersion < 23) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sticky_notes (
            id $idType,
            content $textType,
            colorIndex INTEGER DEFAULT 0,
            createdAt $textType,
            updatedAt $textType
          )
        ''');
      } catch (e) {
        log('Migration Error v23 sticky_notes: $e');
      }
    }
  }

  Future<void> close() async {
    await _databaseOpening;
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _databaseOpening = null;
  }

  Future<void> resetDatabase() async {
    if (_accountId != null) {
      throw StateError(
        'Use Account & Sync to clear this device or delete cloud data.',
      );
    }
    final path = await activePath;
    await close();
    await deleteDatabase(path);
  }

  // Payment Method CRUD
  Future<int> insertPaymentMethod(PaymentMethod paymentMethod) async {
    final db = await instance.database;
    return await db.insert('payment_methods', paymentMethod.toMap());
  }

  Future<List<PaymentMethod>> getPaymentMethods() async {
    final db = await instance.database;
    final result = await db.query('payment_methods');
    return result.map((json) => PaymentMethod.fromMap(json)).toList();
  }

  Future<int> deletePaymentMethod(String id) async {
    final db = await instance.database;
    return await db.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updatePaymentMethod(PaymentMethod paymentMethod) async {
    final db = await instance.database;
    return await db.update(
      'payment_methods',
      paymentMethod.toMap(),
      where: 'id = ?',
      whereArgs: [paymentMethod.id],
    );
  }

  // Projects CRUD
  Future<int> insertProject(Project project) async {
    final db = await instance.database;
    return await db.insert('projects', project.toMap());
  }

  Future<List<Project>> getProjects() async {
    final db = await instance.database;
    final result = await db.query('projects');
    return result.map((json) => Project.fromMap(json)).toList();
  }

  Future<int> deleteProject(String id) async {
    final db = await database;
    return db.transaction((tx) async {
      final tasks = await tx.query(
        'tasks',
        columns: ['id'],
        where: 'projectId=?',
        whereArgs: [id],
      );
      for (final row in tasks) {
        await _deleteTask(tx, row['id']! as String);
      }
      await tx.delete('project_members', where: 'projectId=?', whereArgs: [id]);
      return tx.delete('projects', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<int> updateProject(Project project) async {
    final db = await instance.database;
    return await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  // Tasks CRUD
  Future<int> insertTask(ProjectTask task) async {
    final db = await database;
    return db.transaction((tx) async {
      final result = await tx.insert('tasks', task.toMap());
      await _saveTaskRelations(tx, task);
      return result;
    });
  }

  Future<void> _saveTaskRelations(DatabaseExecutor tx, ProjectTask task) async {
    await tx.delete('task_assignees', where: 'taskId=?', whereArgs: [task.id]);
    for (final memberId in task.assigneeIds) {
      await tx.insert('task_assignees', {
        'taskId': task.id,
        'memberId': memberId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (!task.isPaid) {
      await tx.delete('incomes', where: 'taskId=?', whereArgs: [task.id]);
      return;
    }
    final existing = await tx.query(
      'incomes',
      where: 'taskId=?',
      whereArgs: [task.id],
    );
    if (existing.isNotEmpty) return;
    final categories = await tx.query('income_categories');
    if (categories.isEmpty) {
      await tx.insert('income_categories', {
        'id': 'inc_projects',
        'name': 'Projects',
        'color': 0xFF10B981,
        'icon': 0xe0af,
        'isDefault': 1,
      });
    }
    final category =
        categories.any((c) => c['id'] == 'inc_projects') || categories.isEmpty
        ? 'inc_projects'
        : categories.first['id'];
    await tx.insert('incomes', {
      'id': 'task_income_${task.id}',
      'title': task.name,
      'amount': task.cost,
      'date': DateTime.now().toIso8601String(),
      'categoryId': category,
      'paymentMethodId': task.paymentMethodId,
      'taskId': task.id,
      'note': 'Task payment',
      'currency': task.currency,
    });
  }

  Future<List<ProjectTask>> getTasks(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'projectId = ?',
      whereArgs: [projectId],
    );
    final assigneeMap = await _assigneesByTaskIds(
      result.map((r) => r['id'] as String).toList(),
    );
    return result
        .map(
          (json) => ProjectTask.fromMap(
            json,
            assigneeIds: assigneeMap[json['id']] ?? const [],
          ),
        )
        .toList();
  }

  Future<int> _deleteTask(DatabaseExecutor tx, String id) async {
    await tx.delete('incomes', where: 'taskId=?', whereArgs: [id]);
    await tx.update(
      'expenses',
      {'taskId': null},
      where: 'taskId=?',
      whereArgs: [id],
    );
    await tx.delete('task_assignees', where: 'taskId=?', whereArgs: [id]);
    return tx.delete('tasks', where: 'id=?', whereArgs: [id]);
  }

  Future<int> deleteTask(String id, [String? projectId]) async {
    final db = await database;
    return db.transaction((tx) => _deleteTask(tx, id));
  }

  Future<int> updateTask(ProjectTask task) async {
    final db = await database;
    return db.transaction((tx) async {
      final result = await tx.update(
        'tasks',
        task.toMap(),
        where: 'id=?',
        whereArgs: [task.id],
      );
      await _saveTaskRelations(tx, task);
      return result;
    });
  }

  Future<List<ProjectTask>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks');
    final assigneeMap = await _assigneesByTaskIds(
      result.map((r) => r['id'] as String).toList(),
    );
    return result
        .map(
          (json) => ProjectTask.fromMap(
            json,
            assigneeIds: assigneeMap[json['id']] ?? const [],
          ),
        )
        .toList();
  }

  Future<Map<String, List<String>>> _assigneesByTaskIds(
    List<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return {};
    final db = await instance.database;
    final placeholders = List.filled(taskIds.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT taskId, memberId FROM task_assignees WHERE taskId IN ($placeholders)',
      taskIds,
    );
    final map = <String, List<String>>{};
    for (final row in rows) {
      final taskId = row['taskId'] as String;
      map.putIfAbsent(taskId, () => []).add(row['memberId'] as String);
    }
    return map;
  }

  Future<void> setTaskAssignees(String taskId, List<String> memberIds) async {
    final db = await instance.database;
    await db.delete('task_assignees', where: 'taskId = ?', whereArgs: [taskId]);
    for (final memberId in memberIds.toSet()) {
      await db.insert('task_assignees', {
        'taskId': taskId,
        'memberId': memberId,
      });
    }
  }

  // Project members CRUD
  Future<int> insertProjectMember(ProjectMember member) async {
    final db = await instance.database;
    return await db.insert('project_members', member.toMap());
  }

  Future<List<ProjectMember>> getProjectMembers(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'project_members',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'name ASC',
    );
    return result.map(ProjectMember.fromMap).toList();
  }

  Future<List<ProjectMember>> getAllProjectMembers() async {
    final db = await instance.database;
    final result = await db.query('project_members', orderBy: 'name ASC');
    return result.map(ProjectMember.fromMap).toList();
  }

  Future<int> updateProjectMember(ProjectMember member) async {
    final db = await instance.database;
    return await db.update(
      'project_members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<int> deleteProjectMember(String id) async {
    final db = await instance.database;
    await db.delete('task_assignees', where: 'memberId = ?', whereArgs: [id]);
    return await db.delete('project_members', where: 'id = ?', whereArgs: [id]);
  }

  // Expense Categories CRUD
  Future<int> insertExpenseCategory(ExpenseCategory category) async {
    final db = await instance.database;
    return await db.insert(
      'expense_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<ExpenseCategory>> getExpenseCategories() async {
    final db = await instance.database;
    final result = await db.query(
      'expense_categories',
      orderBy: 'isDefault DESC, name ASC',
    );
    return result.map((json) => ExpenseCategory.fromMap(json)).toList();
  }

  Future<int> updateExpenseCategory(ExpenseCategory category) async {
    final db = await instance.database;
    return await db.update(
      'expense_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteExpenseCategory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'expense_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Expenses CRUD
  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'date DESC');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<List<Expense>> getExpensesByCategory(String categoryId) async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      orderBy: 'date DESC',
    );
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<Expense?> getExpenseByTaskId(String taskId) async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      where: 'taskId = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Expense.fromMap(result.first);
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(String id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpenseByTaskId(String taskId) async {
    final db = await instance.database;
    await db.delete('expenses', where: 'taskId = ?', whereArgs: [taskId]);
  }

  Future<int> countExpensesByCategory(String categoryId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM expenses WHERE categoryId = ?',
      [categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countUsagesOfPaymentMethod(String paymentMethodId) async {
    final db = await instance.database;
    final expenses = await db.rawQuery(
      'SELECT COUNT(*) as c FROM expenses WHERE paymentMethodId = ?',
      [paymentMethodId],
    );
    final tasks = await db.rawQuery(
      'SELECT COUNT(*) as c FROM tasks WHERE paymentMethodId = ?',
      [paymentMethodId],
    );
    final incomes = await db.rawQuery(
      'SELECT COUNT(*) as c FROM incomes WHERE paymentMethodId = ?',
      [paymentMethodId],
    );
    return (Sqflite.firstIntValue(expenses) ?? 0) +
        (Sqflite.firstIntValue(tasks) ?? 0) +
        (Sqflite.firstIntValue(incomes) ?? 0);
  }

  /// Income and expense totals grouped by payment method **and** currency.
  ///
  /// Each row is `{paymentMethodId, currency, incomeTotal, expenseTotal}`.
  /// Wallet balances combine these grouped rows in Dart so only the handful of
  /// currency buckets are converted, never every transaction.
  Future<List<Map<String, Object?>>> getWalletFlowTotals() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT paymentMethodId,
             COALESCE(currency, 'EGP') AS currency,
             SUM(CASE WHEN kind = 'income' THEN amount ELSE 0 END) AS incomeTotal,
             SUM(CASE WHEN kind = 'expense' THEN amount ELSE 0 END) AS expenseTotal
      FROM (
        SELECT paymentMethodId, currency, amount, 'income' AS kind FROM incomes
        UNION ALL
        SELECT paymentMethodId, currency, amount, 'expense' AS kind FROM expenses
      )
      GROUP BY paymentMethodId, COALESCE(currency, 'EGP')
    ''');
  }

  /// Per-project task counts and money totals for non-archived tasks.
  ///
  /// Each row is `{projectId, total, completed, pending, inProgress,
  /// totalEarnings, paidEarnings}`. Mirrors the semantics of the previous
  /// in-Dart aggregations (archived tasks excluded; completed == `isCompleted`).
  Future<List<Map<String, Object?>>> getProjectTaskAggregates() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT projectId,
             COUNT(*) AS total,
             SUM(CASE WHEN isCompleted = 1 THEN 1 ELSE 0 END) AS completed,
             SUM(CASE WHEN status = 'toDo' THEN 1 ELSE 0 END) AS pending,
             SUM(CASE WHEN status = 'inProgress' THEN 1 ELSE 0 END) AS inProgress,
             SUM(cost) AS totalEarnings,
             SUM(CASE WHEN isPaid = 1 THEN cost ELSE 0 END) AS paidEarnings
      FROM tasks
      WHERE isArchived = 0
      GROUP BY projectId
    ''');
  }

  Future<int> insertIncomeCategory(IncomeCategory category) async {
    final db = await instance.database;
    return await db.insert(
      'income_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<IncomeCategory>> getIncomeCategories() async {
    final db = await instance.database;
    final result = await db.query(
      'income_categories',
      orderBy: 'isDefault DESC, name ASC',
    );
    return result.map((json) => IncomeCategory.fromMap(json)).toList();
  }

  Future<int> updateIncomeCategory(IncomeCategory category) async {
    final db = await instance.database;
    return await db.update(
      'income_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteIncomeCategory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'income_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countIncomesByCategory(String categoryId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM incomes WHERE categoryId = ?',
      [categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insertIncome(Income income) async {
    final db = await instance.database;
    return await db.insert('incomes', income.toMap());
  }

  Future<List<Income>> getIncomes() async {
    final db = await instance.database;
    final result = await db.query('incomes', orderBy: 'date DESC');
    return result.map((json) => Income.fromMap(json)).toList();
  }

  Future<Income?> getIncomeByTaskId(String taskId) async {
    final db = await instance.database;
    final result = await db.query(
      'incomes',
      where: 'taskId = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Income.fromMap(result.first);
  }

  Future<int> updateIncome(Income income) async {
    final db = await instance.database;
    return await db.update(
      'incomes',
      income.toMap(),
      where: 'id = ?',
      whereArgs: [income.id],
    );
  }

  Future<int> deleteIncome(String id) async {
    final db = await instance.database;
    return await db.delete('incomes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteIncomeByTaskId(String taskId) async {
    final db = await instance.database;
    await db.delete('incomes', where: 'taskId = ?', whereArgs: [taskId]);
  }

  // Sticky Notes CRUD
  Future<int> insertStickyNote(StickyNote note) async {
    final db = await instance.database;
    return await db.insert('sticky_notes', note.toMap());
  }

  Future<List<StickyNote>> getStickyNotes() async {
    final db = await instance.database;
    final result = await db.query('sticky_notes', orderBy: 'updatedAt DESC');
    return result.map(StickyNote.fromMap).toList();
  }

  Future<int> updateStickyNote(StickyNote note) async {
    final db = await instance.database;
    return await db.update(
      'sticky_notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteStickyNote(String id) async {
    final db = await instance.database;
    return await db.delete('sticky_notes', where: 'id = ?', whereArgs: [id]);
  }
}
