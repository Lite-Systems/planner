import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:planner/core/services/pdf_service.dart';
import 'package:planner/core/utils/no_animation_route.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/screens/projects/screens/add_task_screen.dart';
import 'package:provider/provider.dart';

class TaskArchiveScreen extends StatelessWidget {
  const TaskArchiveScreen({super.key});

  Future<void> _print(
    BuildContext context,
    Project project,
    List<ProjectTask> tasks, {
    required bool share,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final pdf = PdfService();
    final name = 'Archive_${project.name}';
    if (share) {
      final box = context.findRenderObject() as RenderBox?;
      await pdf.shareProjectInvoice(
        project,
        tasks,
        context.locale,
        currency: settings.currency,
        showHourCost: settings.showHourCostInPrint,
        showTaskType: settings.showTaskTypeInPrint,
        showTaskTime: settings.showTaskTimeInPrint,
        showSubtasks: settings.showSubtasksInPrint,
        documentName: name,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } else {
      await pdf.printProjectInvoice(
        project,
        tasks,
        context.locale,
        currency: settings.currency,
        showHourCost: settings.showHourCostInPrint,
        showTaskType: settings.showTaskTypeInPrint,
        showTaskTime: settings.showTaskTimeInPrint,
        showSubtasks: settings.showSubtasksInPrint,
        documentName: name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('taskArchive'.tr())),
      child: SafeArea(
        child: Consumer2<ProjectProvider, SettingsProvider>(
          builder: (context, projects, settings, _) {
            final archived = projects.archivedTasks();
            if (archived.isEmpty) {
              return Center(child: Text('noArchivedTasks'.tr()));
            }

            final grouped = <String, List<ProjectTask>>{};
            for (final task in archived) {
              grouped.putIfAbsent(task.projectId, () => []).add(task);
            }
            final groups = grouped.entries.toList();

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final entry = groups[i];
                return _ProjectArchiveSection(
                  project:
                      projects.projects
                          .where((p) => p.id == entry.key)
                          .firstOrNull ??
                      Project(id: entry.key, name: entry.key, description: ''),
                  tasks: entry.value,
                  settings: settings,
                  onPrint: (project, tasks) =>
                      _print(context, project, tasks, share: false),
                  onShare: (project, tasks) =>
                      _print(context, project, tasks, share: true),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProjectArchiveSection extends StatelessWidget {
  final Project project;
  final List<ProjectTask> tasks;
  final SettingsProvider settings;
  final void Function(Project project, List<ProjectTask> tasks) onPrint;
  final void Function(Project project, List<ProjectTask> tasks) onShare;

  const _ProjectArchiveSection({
    required this.project,
    required this.tasks,
    required this.settings,
    required this.onPrint,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: Text(project.name),
      footer: Text(
        '${tasks.length} • ${settings.formatMoney(tasks.fold<double>(0, (s, t) => s + t.cost))}',
      ),
      children: [
        for (final task in tasks)
          CupertinoListTile(
            title: Text(task.name),
            subtitle: Text(settings.formatMoney(task.cost, task.currency)),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Provider.of<ProjectProvider>(
                  context,
                  listen: false,
                ).restoreArchivedTask(task);
              },
              child: Text('restoreTask'.tr()),
            ),
            onTap: () {
              Navigator.push(
                context,
                NoAnimationPageRoute(
                  builder: (_) =>
                      AddTaskScreen(projectId: project.id, task: task),
                ),
              );
            },
          ),
        CupertinoListTile(
          leading: const FaIcon(FontAwesomeIcons.print, size: 18),
          title: Text('printArchive'.tr()),
          trailing: const CupertinoListTileChevron(),
          onTap: () => onPrint(project, tasks),
        ),
        CupertinoListTile(
          leading: const FaIcon(
            FontAwesomeIcons.whatsapp,
            size: 18,
            color: CupertinoColors.activeGreen,
          ),
          title: Text('shareArchive'.tr()),
          trailing: const CupertinoListTileChevron(),
          onTap: () => onShare(project, tasks),
        ),
      ],
    );
  }
}
