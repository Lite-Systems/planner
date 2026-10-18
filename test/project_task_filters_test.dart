import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/utils/app_thems.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_member.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:planner/screens/projects/screens/project_detail_screen.dart';
import 'package:planner/screens/projects/widgets/task_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final (width, language, scale) in [
    (390.0, 'ar', 1.3),
    (1440.0, 'en', 1.0),
  ]) {
    testWidgets(
      'task filters combine, clear and reset for another project at $width/$language',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final projects = _Projects();
        final settings = SettingsProvider();
        final wallet = WalletProvider();
        addTearDown(projects.dispose);
        addTearDown(settings.dispose);
        addTearDown(wallet.dispose);
        Future<void> pump(String projectId) async {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<ProjectProvider>.value(value: projects),
                ChangeNotifierProvider.value(value: settings),
                ChangeNotifierProvider.value(value: wallet),
              ],
              child: EasyLocalization(
                supportedLocales: const [Locale('ar'), Locale('en')],
                startLocale: Locale(language),
                path: 'assets/translations',
                assetLoader: _Translations(),
                child: Builder(
                  builder: (context) => CupertinoApp(
                    theme: AppThems.darkTheme(),
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: ProjectDetailScreen(
                      project: Project(
                        id: projectId,
                        name: 'Project $projectId',
                        description: '',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        int taskCount() => find.byType(ListView).evaluate().isEmpty
            ? 0
            : tester
                  .widget<ListView>(find.byType(ListView))
                  .semanticChildCount!;
        Future<void> choose(String key) async {
          final finder = find.byKey(ValueKey(key));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        Future<void> search(String text) async {
          await tester.enterText(
            find.byKey(const ValueKey('project-task-search')),
            text,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await pump('p');
        expect(taskCount(), 5); // Archived tasks remain excluded.
        await search(' ALPHA ');
        expect(taskCount(), 2);
        await choose('project-task-filters');
        await choose('task-type-bug');
        expect(taskCount(), 1);
        expect(
          tester.widget<TaskCard>(find.byType(TaskCard)).task.id,
          'progress',
        );
        await choose('task-status-done');
        expect(taskCount(), 0);
        await choose('project-task-clear-filters');
        expect(taskCount(), 5);
        expect(
          tester
              .widget<CupertinoSearchTextField>(
                find.byType(CupertinoSearchTextField),
              )
              .controller!
              .text,
          isEmpty,
        );
        await choose('task-status-done');
        expect(taskCount(), 2); // Includes legacy completed + toDo records.
        await choose('task-payment-paid');
        expect(taskCount(), 1);
        expect(tester.widget<TaskCard>(find.byType(TaskCard)).task.id, 'done');
        await choose('task-member-alice');
        expect(taskCount(), 0); // Member/payment/status are AND, not OR.
        await choose('project-task-clear-filters');
        await search('واجهة');
        expect(taskCount(), 1);
        await choose('task-type-enhancement');
        expect(taskCount(), 1);
        await pump('second');
        expect(taskCount(), 5);
        expect(find.byKey(const ValueKey('task-type-bug')), findsNothing);
        expect(
          tester
              .widget<CupertinoSearchTextField>(
                find.byType(CupertinoSearchTextField),
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: const TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
}

class _Projects extends ProjectProvider {
  @override
  Future<void> loadTasks(String projectId) async {}
  @override
  List<ProjectMember> getMembers(String projectId) => [
    ProjectMember(
      id: 'alice',
      projectId: projectId,
      name: 'Alice',
      color: 0xFFFF8800,
    ),
    ProjectMember(
      id: 'bob',
      projectId: projectId,
      name: 'Bob',
      color: 0xFF0088FF,
    ),
  ];
  @override
  List<ProjectTask> getTasks(String projectId) {
    ProjectTask task(
      String id,
      String name,
      String type,
      String status,
      bool paid,
      String member, {
      bool completed = false,
      bool archived = false,
    }) => ProjectTask(
      id: id,
      projectId: projectId,
      name: name,
      details: '',
      attachments: [],
      startDate: DateTime(2026, 10, 18),
      cost: 5,
      type: type,
      status: status,
      isCompleted: completed,
      isPaid: paid,
      assigneeIds: [member],
      isArchived: archived,
    );
    return [
      task('todo', 'Alpha feature', 'newFeature', 'toDo', false, 'alice'),
      task('progress', 'Alpha repair', 'bug', 'inProgress', true, 'alice'),
      task('done', 'Beta repair', 'bug', 'done', true, 'bob'),
      task(
        'legacy',
        'Old repair',
        'bug',
        'toDo',
        false,
        'alice',
        completed: true,
      ),
      task('arabic', 'تحسين الواجهة', 'enhancement', 'toDo', false, 'alice'),
      task(
        'archived',
        'Alpha archived',
        'bug',
        'done',
        true,
        'alice',
        archived: true,
      ),
    ];
  }
}

class _Translations extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}
