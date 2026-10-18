import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/app_thems.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:planner/screens/projects/screens/projects_screen.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('collapsed project filters lay out on desktop', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProjectProvider(),
        child: const CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(1400, 900)),
            child: AppLayoutHost(child: ProjectsScreen(embedded: true)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'project and task panes scroll independently and switch cleanly',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProjectProvider>(
              create: (_) => _PopulatedProjects(),
            ),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => WalletProvider()),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
            startLocale: const Locale('en'),
            path: 'assets/translations',
            child: Builder(
              builder: (context) => CupertinoApp(
                theme: AppThems.lightTheme(),
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                scrollBehavior: const AppScrollBehavior(),
                home: const AppLayoutHost(
                  child: ProjectsScreen(embedded: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Project 00'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final lists = tester.widgetList<ListView>(find.byType(ListView)).toList();
      expect(lists, hasLength(2));
      expect(identical(lists[0].controller, lists[1].controller), isFalse);
      expect(lists[0].controller!.positions, hasLength(1));
      expect(lists[1].controller!.positions, hasLength(1));
      expect(find.byType(CupertinoScrollbar), findsNWidgets(2));
      await tester.drag(find.byType(ListView).last, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(lists[0].controller!.offset, 0);
      expect(lists[1].controller!.offset, greaterThan(0));
      await tester.tap(find.text('Project 01'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<ListView>(find.byType(ListView).last).controller!.offset,
        0,
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );
}

class _PopulatedProjects extends ProjectProvider {
  final _projects = List.generate(
    30,
    (i) => Project(
      id: '$i',
      name: 'Project ${i.toString().padLeft(2, '0')}',
      description: '',
    ),
  );

  @override
  List<Project> get projects => _projects;

  @override
  List<ProjectTask> getTasks(String projectId) => List.generate(
    50,
    (i) => ProjectTask(
      id: '$projectId-$i',
      projectId: projectId,
      name: 'Task $i',
      details: '',
      attachments: [],
      startDate: DateTime(2026, 10, 18),
      cost: 0,
    ),
  );

  @override
  Future<void> loadTasks(String projectId) async {}
}
