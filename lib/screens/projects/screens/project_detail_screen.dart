import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/core/utils/no_animation_route.dart';

import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../providers/project_provider.dart';
import '../../../models/project.dart';
import '../../../models/project_member.dart';

import 'add_task_screen.dart';
import '../widgets/task_card.dart';
import '../../../core/services/pdf_service.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/project_task.dart';
import '../widgets/project_dialog.dart';
import '../widgets/project_members_sheet.dart';
import '../widgets/voice_task_sheet.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  final bool embedded;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    this.embedded = false,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};
  String _selectedType = 'all';
  String _selectedPaymentStatus = 'all';
  String _selectedMemberId = 'all';
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<ProjectProvider>(
        context,
        listen: false,
      ).loadTasks(widget.project.id);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id == widget.project.id) return;
    _isSelectionMode = false;
    _selectedTaskIds.clear();
    _selectedType = 'all';
    _selectedPaymentStatus = 'all';
    _selectedMemberId = 'all';
    _filtersExpanded = false;
    Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).loadTasks(widget.project.id);
  }

  bool _isGeneratingPdf = false;

  /// Shows/dismisses the modal spinner while the PDF is being rendered on the
  /// background isolate. Dismissed before the print/share UI appears.
  void _setGenerating(bool active) {
    if (!mounted || active == _isGeneratingPdf) return;
    _isGeneratingPdf = active;
    if (active) {
      showCupertinoDialog<void>(
        useRootNavigator: false,
        context: context,
        barrierDismissible: false,
        builder: (_) => const CupertinoAlertDialog(
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _generatePdf(List<ProjectTask> tasks) async {
    final pdfService = PdfService();
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    await pdfService.printProjectInvoice(
      widget.project,
      tasks,
      context.locale,
      currency: settingsProvider.currency,
      showHourCost: settingsProvider.showHourCostInPrint,
      showTaskType: settingsProvider.showTaskTypeInPrint,
      showTaskTime: settingsProvider.showTaskTimeInPrint,
      showSubtasks: settingsProvider.showSubtasksInPrint,
      onGenerating: _setGenerating,
    );
  }

  Future<void> _sharePdf(
    List<ProjectTask> tasks, {
    Rect? sharePositionOrigin,
  }) async {
    final pdfService = PdfService();
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    await pdfService.shareProjectInvoice(
      widget.project,
      tasks,
      context.locale,
      currency: settingsProvider.currency,
      showHourCost: settingsProvider.showHourCostInPrint,
      showTaskType: settingsProvider.showTaskTypeInPrint,
      showTaskTime: settingsProvider.showTaskTimeInPrint,
      showSubtasks: settingsProvider.showSubtasksInPrint,
      sharePositionOrigin: sharePositionOrigin,
      onGenerating: _setGenerating,
    );
  }

  void _confirmArchive(BuildContext context, {Set<String>? ids}) {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final eligible = provider
        .getTasks(widget.project.id)
        .where((t) => t.canArchive)
        .where((t) => ids == null || ids.contains(t.id))
        .length;

    if (eligible == 0) {
      showCupertinoDialog(
        useRootNavigator: false,
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('archiveTasks'.tr()),
          content: Text('onlyCompletedPaidCanArchive'.tr()),
          actions: [
            CupertinoDialogAction(
              child: Text('ok'.tr()),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('archiveTasks'.tr()),
        content: Text(
          'archiveTasksConfirm'.tr(namedArgs: {'count': '$eligible'}),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: Text('archiveAction'.tr()),
            onPressed: () {
              provider.archiveTasks(widget.project.id, ids: ids);
              Navigator.pop(context);
              if (_isSelectionMode) {
                setState(() {
                  _isSelectionMode = false;
                  _selectedTaskIds.clear();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context) {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('deleteProject'.tr()),
        content: Text('deleteProjectConfirm'.tr()),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('delete'.tr()),
            onPressed: () {
              Provider.of<ProjectProvider>(
                context,
                listen: false,
              ).deleteProject(widget.project.id);
              Navigator.pop(context); // Close dialog
              if (!widget.embedded && Navigator.of(context).canPop()) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  bool get _hasFilters =>
      _selectedType != 'all' ||
      _selectedPaymentStatus != 'all' ||
      _selectedMemberId != 'all';

  int get _activeFilterCount =>
      (_selectedType != 'all' ? 1 : 0) +
      (_selectedPaymentStatus != 'all' ? 1 : 0) +
      (_selectedMemberId != 'all' ? 1 : 0);

  void _clearFilters() {
    setState(() {
      _selectedType = 'all';
      _selectedPaymentStatus = 'all';
      _selectedMemberId = 'all';
    });
  }

  Widget _buildFilters(List<ProjectMember> members) {
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              onPressed: () =>
                  setState(() => _filtersExpanded = !_filtersExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    _filtersExpanded
                        ? FontAwesomeIcons.chevronUp
                        : FontAwesomeIcons.sliders,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text('filterProjects'.tr(), style: AppText.caption(context)),
                  if (_hasFilters) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _activeFilterCount.toString(),
                        style: AppText.caption(
                          context,
                        ).copyWith(color: CupertinoColors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: _filtersExpanded
              ? _buildFilterPanel(members)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildFilterPanel(List<ProjectMember> members) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.separator(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'all'.tr(),
                  isSelected: _selectedType == 'all',
                  onTap: () => setState(() => _selectedType = 'all'),
                ),
                _buildFilterChip(
                  label: 'newFeature'.tr(),
                  isSelected: _selectedType == 'newFeature',
                  onTap: () => setState(() => _selectedType = 'newFeature'),
                ),
                _buildFilterChip(
                  label: 'bug'.tr(),
                  isSelected: _selectedType == 'bug',
                  onTap: () => setState(() => _selectedType = 'bug'),
                ),
                _buildFilterChip(
                  label: 'enhancement'.tr(),
                  isSelected: _selectedType == 'enhancement',
                  onTap: () => setState(() => _selectedType = 'enhancement'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'all'.tr(),
                  isSelected: _selectedPaymentStatus == 'all',
                  onTap: () => setState(() => _selectedPaymentStatus = 'all'),
                ),
                _buildFilterChip(
                  label: 'paid'.tr(),
                  isSelected: _selectedPaymentStatus == 'paid',
                  onTap: () => setState(() => _selectedPaymentStatus = 'paid'),
                ),
                _buildFilterChip(
                  label: 'unpaid'.tr(),
                  isSelected: _selectedPaymentStatus == 'unpaid',
                  onTap: () =>
                      setState(() => _selectedPaymentStatus = 'unpaid'),
                ),
              ],
            ),
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'allMembers'.tr(),
                    isSelected: _selectedMemberId == 'all',
                    onTap: () => setState(() => _selectedMemberId = 'all'),
                  ),
                  ...members.map(
                    (m) => _buildFilterChip(
                      label: m.name,
                      isSelected: _selectedMemberId == m.id,
                      onTap: () => setState(() => _selectedMemberId = m.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_hasFilters)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CupertinoButton(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                onPressed: _clearFilters,
                child: Text('clearFilters'.tr()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AppClickable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.elevatedBackground(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Text(
          label,
          style: isSelected
              ? AppText.caption(context).copyWith(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                )
              : AppText.caption(
                  context,
                ).copyWith(color: CupertinoColors.label, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        final project = provider.projects.firstWhere(
          (p) => p.id == widget.project.id,
          orElse: () => widget.project,
        );
        return CupertinoPageScaffold(
          navigationBar: AppNavigationBar(
            middle: Text(project.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isSelectionMode) ...[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const FaIcon(FontAwesomeIcons.userGroup, size: 18),
                    onPressed: () =>
                        ProjectMembersSheet.show(context, widget.project.id),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const FaIcon(FontAwesomeIcons.penToSquare, size: 20),
                    onPressed: () =>
                        ProjectDialog.show(context, project: project),
                  ),
                  if (provider.archivableCount(widget.project.id) > 0)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const FaIcon(
                        FontAwesomeIcons.boxArchive,
                        size: 18,
                      ),
                      onPressed: () => _confirmArchive(context),
                    ),
                ],
                if (_isSelectionMode) ...[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const FaIcon(
                      FontAwesomeIcons.trashCan,
                      color: CupertinoColors.destructiveRed,
                      size: 20,
                    ),
                    onPressed: () {
                      if (_selectedTaskIds.isEmpty) return;
                      showCupertinoDialog(
                        useRootNavigator: false,
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: Text('deleteTasks'.tr()),
                          content: Text('deleteTasksConfirm'.tr()),
                          actions: [
                            CupertinoDialogAction(
                              child: Text('cancel'.tr()),
                              onPressed: () => Navigator.pop(context),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: Text('delete'.tr()),
                              onPressed: () {
                                final provider = Provider.of<ProjectProvider>(
                                  context,
                                  listen: false,
                                );
                                for (var id in _selectedTaskIds) {
                                  provider.deleteTask(id, widget.project.id);
                                }
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedTaskIds.clear();
                                });
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      size: 20,
                      color: CupertinoColors.activeGreen,
                    ),
                    onPressed: () {
                      if (_selectedTaskIds.isEmpty) return;
                      final provider = Provider.of<ProjectProvider>(
                        context,
                        listen: false,
                      );
                      final allTasks = provider.getTasks(widget.project.id);
                      final selectedTasks = allTasks
                          .where((t) => _selectedTaskIds.contains(t.id))
                          .toList();
                      if (selectedTasks.isNotEmpty) {
                        _sharePdf(
                          selectedTasks,
                          sharePositionOrigin: _shareOrigin(context),
                        );
                        setState(() {
                          _isSelectionMode = false;
                          _selectedTaskIds.clear();
                        });
                      }
                    },
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const FaIcon(FontAwesomeIcons.print, size: 20),
                    onPressed: () {
                      if (_selectedTaskIds.isEmpty) return;
                      final provider = Provider.of<ProjectProvider>(
                        context,
                        listen: false,
                      );
                      final allTasks = provider.getTasks(widget.project.id);
                      final selectedTasks = allTasks
                          .where((t) => _selectedTaskIds.contains(t.id))
                          .toList();
                      if (selectedTasks.isNotEmpty) {
                        _generatePdf(selectedTasks);
                        setState(() {
                          _isSelectionMode = false;
                          _selectedTaskIds.clear();
                        });
                      }
                    },
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const FaIcon(FontAwesomeIcons.boxArchive, size: 18),
                    onPressed: () {
                      if (_selectedTaskIds.isEmpty) return;
                      _confirmArchive(
                        context,
                        ids: Set<String>.from(_selectedTaskIds),
                      );
                    },
                  ),
                ],
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Text(_isSelectionMode ? 'cancel'.tr() : 'select'.tr()),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      _selectedTaskIds.clear();
                    });
                  },
                ),
                if (!_isSelectionMode)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const FaIcon(FontAwesomeIcons.trashCan, size: 20),
                    onPressed: () => _confirmDeleteProject(context),
                  ),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    if (project.customer != null &&
                        project.customer!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          0,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            project.customer!,
                            style: AppText.bodySecondary(context),
                          ),
                        ),
                      ),
                    _buildFilters(provider.getMembers(widget.project.id)),
                    Expanded(
                      child: Consumer<ProjectProvider>(
                        builder: (_, provider, child) {
                          var tasks = provider.activeTasks(widget.project.id);

                          // Apply Filters
                          if (_selectedType != 'all') {
                            tasks = tasks
                                .where((t) => t.type == _selectedType)
                                .toList();
                          }

                          if (_selectedPaymentStatus != 'all') {
                            final isPaidFilter =
                                _selectedPaymentStatus == 'paid';
                            tasks = tasks
                                .where((t) => t.isPaid == isPaidFilter)
                                .toList();
                          }

                          if (_selectedMemberId != 'all') {
                            tasks = tasks
                                .where(
                                  (t) =>
                                      t.assigneeIds.contains(_selectedMemberId),
                                )
                                .toList();
                          }

                          if (tasks.isEmpty) {
                            return Center(child: Text('noData'.tr()));
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            primary: false,
                            itemCount: tasks.length,
                            itemBuilder: (_, index) {
                              final task = tasks[index];
                              return TaskCard(
                                task: task,
                                isSelectionMode: _isSelectionMode,
                                selectedTaskIds: _selectedTaskIds,
                                onTap: () {
                                  if (_isSelectionMode) {
                                    setState(() {
                                      if (_selectedTaskIds.contains(task.id)) {
                                        _selectedTaskIds.remove(task.id);
                                      } else {
                                        _selectedTaskIds.add(task.id);
                                      }
                                    });
                                  } else {
                                    Navigator.push(
                                      context,
                                      NoAnimationPageRoute(
                                        builder: (_) => AddTaskScreen(
                                          projectId: widget.project.id,
                                          task: task,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton.filled(
                              padding: EdgeInsets.zero,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(CupertinoIcons.add, size: 18),
                                  const SizedBox(width: 6),
                                  Text('addTask'.tr()),
                                ],
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  NoAnimationPageRoute(
                                    builder: (_) => AddTaskScreen(
                                      projectId: widget.project.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              showCupertinoModalPopup(
                                useRootNavigator: false,
                                context: context,
                                builder: (_) => VoiceTaskSheet(
                                  projectId: widget.project.id,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    AppColors.expensePrimary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                boxShadow: AppShadows.hero(
                                  context,
                                  AppColors.expensePrimary,
                                  alpha: 0.25,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.mic_fill,
                                    color: CupertinoColors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'voiceCreate'.tr(),
                                    style: AppText.body(context).copyWith(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Floating Share/Print buttons for all tasks
                if (!_isSelectionMode)
                  Consumer<ProjectProvider>(
                    builder: (context, provider, _) {
                      final tasks = provider.activeTasks(widget.project.id);
                      if (tasks.isEmpty) return const SizedBox.shrink();

                      return Positioned(
                        bottom: 80,
                        right: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _sharePdf(
                                tasks,
                                sharePositionOrigin: _shareOrigin(context),
                              ),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: CupertinoColors.activeGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.whatsapp,
                                    color: CupertinoColors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _generatePdf(tasks),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey.withValues(
                                    alpha: 0.8,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.print,
                                    color: CupertinoColors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
