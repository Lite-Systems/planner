import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/project_member.dart';
import '../models/project_task.dart';
import '../core/services/database_helper.dart';
import '../core/services/notification_service.dart';

typedef TaskPaidCallback = Future<void> Function(ProjectTask task, bool isPaid);

class ProjectProvider with ChangeNotifier {
  List<Project> _projects = [];
  final Map<String, List<ProjectTask>> _tasks = {}; // projectId -> tasks
  final Map<String, List<ProjectMember>> _members = {}; // projectId -> members

  /// Cached task aggregates, refreshed from SQL once per mutation so summary
  /// widgets never re-scan the task list on every build.
  _TaskStats _stats = _TaskStats.empty;

  /// Optional callback fired when a task's isPaid status changes.
  /// Wired to IncomeProvider in HomeScreen after providers are available.
  TaskPaidCallback? onTaskPaidChanged;
  Future<void> Function()? onFinancialDataChanged;

  List<Project> get projects => _projects;

  List<ProjectTask> getTasks(String projectId) {
    return _tasks[projectId] ?? [];
  }

  List<ProjectMember> getMembers(String projectId) {
    return _members[projectId] ?? [];
  }

  List<ProjectTask> activeTasks(String projectId) {
    return getTasks(projectId).where((t) => !t.isArchived).toList();
  }

  List<ProjectTask> archivedTasks({String? projectId}) {
    final source = projectId == null
        ? _tasks.values.expand((e) => e)
        : getTasks(projectId);
    return source.where((t) => t.isArchived).toList();
  }

  int archivableCount(String projectId) {
    return getTasks(projectId).where((t) => t.canArchive).length;
  }

  Future<int> archiveTasks(String projectId, {Iterable<String>? ids}) async {
    var eligible = getTasks(projectId).where((t) => t.canArchive);
    if (ids != null) {
      final idSet = ids.toSet();
      eligible = eligible.where((t) => idSet.contains(t.id));
    }
    final list = eligible.toList();
    if (list.isEmpty) return 0;

    final tasks = _tasks[projectId];
    for (final task in list) {
      final archived = task.copyWith(isArchived: true);
      await DatabaseHelper.instance.updateTask(archived);
      final index = tasks?.indexWhere((t) => t.id == archived.id) ?? -1;
      if (index != -1) tasks![index] = archived;
      await NotificationService().cancelTaskReminder(archived.id);
    }
    // One aggregate refresh and one notification for the whole batch.
    await _refreshStats();
    notifyListeners();
    return list.length;
  }

  Future<void> restoreArchivedTask(ProjectTask task) {
    return updateTask(task.copyWith(isArchived: false));
  }

  List<ProjectMember> assigneesFor(ProjectTask task) {
    final members = getMembers(task.projectId);
    if (task.assigneeIds.isEmpty || members.isEmpty) return const [];
    final idSet = task.assigneeIds.toSet();
    return members.where((m) => idSet.contains(m.id)).toList();
  }

  int get totalTasksCount => _stats.total;
  int get completedTasksCount => _stats.completed;
  int get pendingTasksCount => _stats.pending;
  int get inProgressTasksCount => _stats.inProgress;
  double get totalEarnings => _stats.totalEarnings;
  double get paidEarnings => _stats.paidEarnings;
  double get unpaidEarnings => _stats.totalEarnings - _stats.paidEarnings;

  /// Recomputes the cached task aggregates with a single grouped SQL query.
  Future<void> _refreshStats() async {
    try {
      final rows = await DatabaseHelper.instance.getProjectTaskAggregates();
      var total = 0, completed = 0, pending = 0, inProgress = 0;
      var totalEarnings = 0.0, paidEarnings = 0.0;
      for (final row in rows) {
        total += (row['total'] as num?)?.toInt() ?? 0;
        completed += (row['completed'] as num?)?.toInt() ?? 0;
        pending += (row['pending'] as num?)?.toInt() ?? 0;
        inProgress += (row['inProgress'] as num?)?.toInt() ?? 0;
        totalEarnings += (row['totalEarnings'] as num?)?.toDouble() ?? 0;
        paidEarnings += (row['paidEarnings'] as num?)?.toDouble() ?? 0;
      }
      _stats = _TaskStats(
        total: total,
        completed: completed,
        pending: pending,
        inProgress: inProgress,
        totalEarnings: totalEarnings,
        paidEarnings: paidEarnings,
      );
    } catch (e) {
      debugPrint('ProjectProvider _refreshStats error: $e');
    }
  }

  Future<void> loadData() async {
    try {
      _projects = await DatabaseHelper.instance.getProjects();
      final allTasks = await DatabaseHelper.instance.getAllTasks();
      _tasks.clear();
      for (var task in allTasks) {
        _tasks.putIfAbsent(task.projectId, () => []).add(task);
      }
      final allMembers = await DatabaseHelper.instance.getAllProjectMembers();
      _members.clear();
      for (final member in allMembers) {
        _members.putIfAbsent(member.projectId, () => []).add(member);
      }
      for (final project in _projects) {
        _tasks.putIfAbsent(project.id, () => []);
        _members.putIfAbsent(project.id, () => []);
      }
      await _refreshStats();
    } catch (e) {
      debugPrint('ProjectProvider loadData error: $e');
    }
    notifyListeners();
  }

  Future<void> loadTasks(String projectId) async {
    // The initial load already includes every project's tasks and members.
    // Reopening a pane should not query SQLite or rebuild the whole dashboard.
    if (_tasks.containsKey(projectId) && _members.containsKey(projectId)) {
      return;
    }
    try {
      _tasks[projectId] = await DatabaseHelper.instance.getTasks(projectId);
      _members[projectId] = await DatabaseHelper.instance.getProjectMembers(
        projectId,
      );
      await _refreshStats();
    } catch (e) {
      debugPrint('ProjectProvider loadTasks error: $e');
    }
    notifyListeners();
  }

  Future<void> addProject(Project project) async {
    await DatabaseHelper.instance.insertProject(project);
    _projects.add(project);
    _members[project.id] = [];
    notifyListeners();
  }

  Future<void> updateProject(Project project) async {
    await DatabaseHelper.instance.updateProject(project);
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project;
      notifyListeners();
    }
  }

  Future<void> deleteProject(String id) async {
    await DatabaseHelper.instance.deleteProject(id);
    await onFinancialDataChanged?.call();
    _projects.removeWhere((p) => p.id == id);
    _tasks.remove(id);
    _members.remove(id);
    await _refreshStats();
    notifyListeners();
  }

  Future<void> addMember(ProjectMember member) async {
    await DatabaseHelper.instance.insertProjectMember(member);
    _members.putIfAbsent(member.projectId, () => []).add(member);
    notifyListeners();
  }

  Future<void> updateMember(ProjectMember member) async {
    await DatabaseHelper.instance.updateProjectMember(member);
    final list = _members[member.projectId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      list[index] = member;
      notifyListeners();
    }
  }

  Future<void> deleteMember(String memberId, String projectId) async {
    await DatabaseHelper.instance.deleteProjectMember(memberId);
    _members[projectId]?.removeWhere((m) => m.id == memberId);
    final tasks = _tasks[projectId];
    if (tasks != null) {
      for (var i = 0; i < tasks.length; i++) {
        if (tasks[i].assigneeIds.contains(memberId)) {
          tasks[i] = tasks[i].copyWith(
            assigneeIds: tasks[i].assigneeIds
                .where((id) => id != memberId)
                .toList(),
          );
        }
      }
    }
    notifyListeners();
  }

  Future<void> setTaskAssignees(String taskId, List<String> memberIds) async {
    await DatabaseHelper.instance.setTaskAssignees(taskId, memberIds);
    for (final entry in _tasks.entries) {
      final index = entry.value.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        entry.value[index] = entry.value[index].copyWith(
          assigneeIds: List<String>.from(memberIds),
        );
        notifyListeners();
        return;
      }
    }
  }

  Future<void> addTask(ProjectTask task) async {
    await DatabaseHelper.instance.insertTask(task);
    if (task.isPaid) await onFinancialDataChanged?.call();
    _tasks.putIfAbsent(task.projectId, () => []).add(task);
    await _syncTaskReminder(task);
    await _refreshStats();
    notifyListeners();
  }

  Future<void> updateTask(ProjectTask task) async {
    final existingTask = _tasks[task.projectId]?.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );
    final paymentChanged =
        existingTask != null && existingTask.isPaid != task.isPaid;

    ProjectTask taskToUpdate = task;
    if (task.status == 'done' && task.timerEndAt == null) {
      taskToUpdate = task.copyWith(
        timerEndAt: DateTime.now(),
        timerStartAt: task.timerStartAt ?? task.startDate,
      );
    }
    await DatabaseHelper.instance.updateTask(taskToUpdate);
    if (_tasks.containsKey(taskToUpdate.projectId)) {
      final index = _tasks[taskToUpdate.projectId]!.indexWhere(
        (t) => t.id == taskToUpdate.id,
      );
      if (index != -1) {
        _tasks[taskToUpdate.projectId]![index] = taskToUpdate;
      }
    }
    await _refreshStats();
    notifyListeners();
    await _syncTaskReminder(taskToUpdate);
    if (paymentChanged) await onFinancialDataChanged?.call();
    if (paymentChanged && onTaskPaidChanged != null) {
      await onTaskPaidChanged!(taskToUpdate, taskToUpdate.isPaid);
    }
  }

  Future<void> deleteTask(String id, String projectId) async {
    await DatabaseHelper.instance.deleteTask(id);
    await onFinancialDataChanged?.call();
    await NotificationService().cancelTaskReminder(id);
    if (_tasks.containsKey(projectId)) {
      _tasks[projectId]!.removeWhere((t) => t.id == id);
      await _refreshStats();
      notifyListeners();
    }
  }

  Future<void> refreshReminders() async {
    await NotificationService().cancelAllTaskReminders();
    for (final task in _tasks.values.expand((tasks) => tasks)) {
      await _syncTaskReminder(task);
    }
  }

  Future<void> _syncTaskReminder(ProjectTask task) async {
    if (task.isCompleted || task.status == 'done' || task.isArchived) {
      await NotificationService().cancelTaskReminder(task.id);
      return;
    }
    await NotificationService().scheduleTaskReminder(
      taskId: task.id,
      title: 'taskDueReminderTitle'.tr(),
      body: 'taskDueReminderBody'.tr(namedArgs: {'name': task.name}),
      startDate: task.startDate,
    );
  }

  Future<void> toggleTaskTimer(String taskId, String projectId) async {
    final tasks = _tasks[projectId];
    if (tasks == null) return;

    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = tasks[index];
    final now = DateTime.now();
    ProjectTask updatedTask;

    if (task.isTimerRunning) {
      final startTime = task.lastStartTime ?? now;
      final difference = now.difference(startTime).inSeconds;
      final newTimeSpent = task.timeSpentInSeconds + difference;

      double newCost = task.cost;
      if (task.hourlyRate > 0) {
        newCost = (newTimeSpent / 3600.0) * task.hourlyRate;
        newCost = double.parse(newCost.toStringAsFixed(2));
      }

      updatedTask = task.copyWith(
        timeSpentInSeconds: newTimeSpent,
        cost: newCost,
        isTimerRunning: false,
        lastStartTime: null,
        timerEndAt: now,
      );
    } else {
      updatedTask = task.copyWith(
        isTimerRunning: true,
        lastStartTime: now,
        timerStartAt: task.timerStartAt ?? now,
      );
    }

    await updateTask(updatedTask);
  }
}

/// Cached task aggregates (non-archived tasks), refreshed from SQL.
class _TaskStats {
  const _TaskStats({
    required this.total,
    required this.completed,
    required this.pending,
    required this.inProgress,
    required this.totalEarnings,
    required this.paidEarnings,
  });

  static const empty = _TaskStats(
    total: 0,
    completed: 0,
    pending: 0,
    inProgress: 0,
    totalEarnings: 0,
    paidEarnings: 0,
  );

  final int total;
  final int completed;
  final int pending;
  final int inProgress;
  final double totalEarnings;
  final double paidEarnings;
}
