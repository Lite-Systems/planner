import 'package:planner/core/utils/app_colors.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/core/utils/timer_ticker.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.onTap,
    required this.task,
    this.isSelectionMode = false,
    this.selectedTaskIds = const {},
  });
  final Function()? onTap;
  final bool isSelectionMode;
  final Set<String> selectedTaskIds;
  final ProjectTask task;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    // Subscribe only to the settings that affect this card's amounts;
    // unrelated settings churn (theme, rate refresh, …) must not rebuild it.
    context.select<SettingsProvider, (bool, String)>(
      (s) => (s.hideAmounts, s.currency),
    );
    final settings = context.read<SettingsProvider>();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: AppCard.container(
            context,
            border:
                widget.isSelectionMode &&
                    widget.selectedTaskIds.contains(task.id)
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              if (widget.isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: FaIcon(
                    widget.selectedTaskIds.contains(task.id)
                        ? FontAwesomeIcons.solidCircleCheck
                        : FontAwesomeIcons.circle,
                    color: widget.selectedTaskIds.contains(task.id)
                        ? AppColors.primary
                        : CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            task.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              settings.formatMoney(task.cost, task.currency),
                              style: const TextStyle(
                                color: CupertinoColors.systemGreen,
                              ),
                            ),
                            if (task.estimatedTime > 0)
                              Text(
                                '${task.estimatedTime} ${'hours'.tr()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: task.status == 'done'
                                ? CupertinoColors.systemGreen.withValues(
                                    alpha: 0.1,
                                  )
                                : (task.status == 'inProgress'
                                      ? CupertinoColors.systemOrange.withValues(
                                          alpha: 0.1,
                                        )
                                      : CupertinoColors.systemGrey.withValues(
                                          alpha: 0.1,
                                        )),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.status.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: task.status == 'done'
                                  ? CupertinoColors.systemGreen
                                  : (task.status == 'inProgress'
                                        ? CupertinoColors.systemOrange
                                        : CupertinoColors.systemGrey),
                            ),
                          ),
                        ),
                        // Timer Display — ticks itself every second; only the
                        // elapsed time inside this chip rebuilds, never the card.
                        _LiveTimerChip(task: task),
                        // Timer Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              // Prevent triggering row tap
                              Provider.of<ProjectProvider>(
                                context,
                                listen: false,
                              ).toggleTaskTimer(task.id, task.projectId);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: task.isTimerRunning
                                    ? CupertinoColors.destructiveRed.withValues(
                                        alpha: 0.1,
                                      )
                                    : AppColors.primary.withValues(alpha: 0.1),
                              ),
                              child: FaIcon(
                                task.isTimerRunning
                                    ? FontAwesomeIcons.stop
                                    : FontAwesomeIcons.play,
                                size: 12,
                                color: task.isTimerRunning
                                    ? CupertinoColors.destructiveRed
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.timerStartAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 2, right: 2),
                            child: FaIcon(
                              FontAwesomeIcons.clockRotateLeft,
                              size: 10,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${'timerStart'.tr()}: ${DateFormat('HH:mm', 'en').format(task.timerStartAt!)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          if (task.timerEndAt != null) ...[
                            Text(
                              ' - ${'timerEnd'.tr()}: ${DateFormat('HH:mm', 'en').format(task.timerEndAt!)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (task.details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          task.details,
                          maxLines: 2,
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (task.subTasks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final doneCount = task.subTasks
                              .where((s) => s['isDone'] == true)
                              .length;
                          final totalCount = task.subTasks.length;
                          final progress = doneCount / totalCount;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'todoList'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                  Text(
                                    '$doneCount/$totalCount (${(progress * 100).toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.elevatedBackground(context),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: progress == 1.0
                                          ? CupertinoColors.activeGreen
                                          : AppColors.primary,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        buildTypeTag(task.type),
                        buildPaymentTag(context, task),
                        _TaskAssigneeChips(task: task),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPaymentTag(BuildContext context, ProjectTask task) {
    return Selector<WalletProvider, String?>(
      selector: (_, walletProvider) => walletProvider.paymentMethods
          .where((m) => m.id == task.paymentMethodId)
          .firstOrNull
          ?.name,
      builder: (context, paymentName, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: task.isPaid
                ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                : CupertinoColors.systemOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                task.isPaid
                    ? FontAwesomeIcons.circleCheck
                    : FontAwesomeIcons.circleInfo,
                size: 10,
                color: task.isPaid
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemOrange,
              ),
              const SizedBox(width: 4),
              Text(
                task.isPaid ? (paymentName ?? 'paid'.tr()) : 'unpaid'.tr(),
                style: TextStyle(
                  fontSize: 10,
                  color: task.isPaid
                      ? CupertinoColors.systemGreen
                      : CupertinoColors.systemOrange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget buildTypeTag(String type) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      type.tr(),
      style: const TextStyle(fontSize: 12, color: AppColors.primary),
    ),
  );
}

/// Assignee avatar chips for a task. Isolated into its own widget so a member
/// change rebuilds only these chips instead of the entire task card.
class _TaskAssigneeChips extends StatelessWidget {
  const _TaskAssigneeChips({required this.task});

  final ProjectTask task;

  @override
  Widget build(BuildContext context) {
    final assignees = context.watch<ProjectProvider>().assigneesFor(task);
    if (assignees.isEmpty) return const SizedBox.shrink();
    final visible = assignees.take(3).toList();
    final overflow = assignees.length - visible.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 6),
        ...visible.map((m) {
          final color = Color(m.color);
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text(
                m.initials,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          );
        }),
        if (overflow > 0)
          Text(
            '+$overflow',
            style: const TextStyle(
              fontSize: 11,
              color: CupertinoColors.systemGrey,
            ),
          ),
      ],
    );
  }
}

/// Elapsed-time chip for a task. Runs its own one-second ticker so only this
/// chip rebuilds per tick — the surrounding card stays static, which matters
/// on desktop where many cards can be visible at once.
class _LiveTimerChip extends StatefulWidget {
  const _LiveTimerChip({required this.task});

  final ProjectTask task;

  @override
  State<_LiveTimerChip> createState() => _LiveTimerChipState();
}

class _LiveTimerChipState extends State<_LiveTimerChip> {
  bool _attached = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_LiveTimerChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.isTimerRunning != oldWidget.task.isTimerRunning) _sync();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// Attaches to the shared one-second ticker only while this task's timer is
  /// running. The ticker stops itself once the last chip detaches — on pause,
  /// completion, archive, deletion, or when the card leaves the viewport.
  void _sync() {
    if (widget.task.isTimerRunning) {
      if (!_attached) {
        _attached = true;
        TimerTicker.instance.acquire();
      }
    } else {
      _detach();
    }
  }

  void _detach() {
    if (!_attached) return;
    _attached = false;
    TimerTicker.instance.release();
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inHours)}:'
        '${twoDigits(duration.inMinutes.remainder(60))}:'
        '${twoDigits(duration.inSeconds.remainder(60))}';
  }

  int get _currentSeconds {
    final task = widget.task;
    var seconds = task.timeSpentInSeconds;
    if (task.isTimerRunning && task.lastStartTime != null) {
      seconds += DateTime.now().difference(task.lastStartTime!).inSeconds;
    }
    return seconds;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    // Only running-timer chips listen to the shared ticker, so a static chip
    // never rebuilds while some other task's timer is ticking.
    if (!task.isTimerRunning) return _buildChip(context, task);
    return ValueListenableBuilder<int>(
      valueListenable: TimerTicker.instance.tick,
      builder: (context, _, _) => _buildChip(context, task),
    );
  }

  Widget _buildChip(BuildContext context, ProjectTask task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: task.isTimerRunning
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.elevatedBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isTimerRunning
              ? AppColors.primary
              : AppColors.separator(context),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.clock,
            size: 12,
            color: task.isTimerRunning
                ? AppColors.primary
                : CupertinoColors.systemGrey,
          ),
          const SizedBox(width: 4),
          Text(
            _formatDuration(_currentSeconds),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: task.isTimerRunning
                  ? AppColors.primary
                  : CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
