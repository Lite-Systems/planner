import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/no_animation_route.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/screens/projects/screens/add_task_screen.dart';
import 'package:planner/screens/projects/widgets/task_card.dart';
import 'package:provider/provider.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  String _statusFilter = 'all';

  List<ProjectTask> _filtered(List<ProjectTask> tasks) {
    if (_statusFilter == 'all') return tasks;
    return tasks.where((t) => t.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(middle: Text('todos'.tr())),
      child: SafeArea(
        child: Consumer<ProjectProvider>(
          builder: (context, provider, _) {
            final allTasks =
                provider.projects
                    .expand((p) => provider.activeTasks(p.id))
                    .toList()
                  ..sort((a, b) => b.startDate.compareTo(a.startDate));
            final tasks = _filtered(allTasks);
            final projectName = {
              for (final p in provider.projects) p.id: p.name,
            };

            return AppLayout.constrain(
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: CupertinoSlidingSegmentedControl<String>(
                      backgroundColor: AppColors.elevatedBackground(context),
                      thumbColor: AppColors.cardBackground(context),
                      groupValue: _statusFilter,
                      children: {
                        'all': Text('allStatuses'.tr()),
                        'toDo': Text('toDo'.tr()),
                        'inProgress': Text('inProgress'.tr()),
                        'done': Text('done'.tr()),
                      },
                      onValueChanged: (value) {
                        if (value == null) return;
                        setState(() => _statusFilter = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: tasks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.listCheck,
                                  size: 40,
                                  color: AppColors.secondaryLabel(context),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'noTodos'.tr(),
                                  style: TextStyle(
                                    color: AppColors.secondaryLabel(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      0,
                                    ),
                                    child: Text(
                                      projectName[task.projectId] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryLabel(
                                          context,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TaskCard(
                                    task: task,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        NoAnimationPageRoute(
                                          builder: (_) => AddTaskScreen(
                                            task: task,
                                            projectId: task.projectId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
              maxWidth: 880,
            );
          },
        ),
      ),
    );
  }
}
