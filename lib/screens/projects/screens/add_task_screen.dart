import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key, this.task, required this.projectId});
  final ProjectTask? task;
  final String projectId;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final nameController = TextEditingController(text: '');
  final detailsController = TextEditingController(text: '');
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  final ValueNotifier<String?> _listeningFieldNotifier = ValueNotifier<String?>(
    null,
  );
  String? get _listeningFieldName => _listeningFieldNotifier.value;
  final costController = TextEditingController(text: '');
  final estimatedTimeController = TextEditingController(text: '');
  final hourlyRateController = TextEditingController(text: '');
  final hoursController = TextEditingController(text: '');
  final minutesController = TextEditingController(text: '');
  DateTime startDate = DateTime.now();
  DateTime? endDate;
  String status = 'toDo';
  String type = 'newFeature';
  String _currency = "EGP";
  List<Map<String, dynamic>> subTasks = [];
  bool isPaid = false;
  bool isArchived = false;
  String? selectedPaymentMethodId;
  double _expectedCost = 0.0;
  final Set<String> selectedAssigneeIds = {};
  final todoController = TextEditingController();
  final statusMap = {
    'toDo': 'toDo'.tr(),
    'inProgress': 'inProgress'.tr(),
    'done': 'done'.tr(),
  };
  final typeMap = {
    'newFeature': 'newFeature'.tr(),
    'bug': 'bug'.tr(),
    'enhancement': 'enhancement'.tr(),
  };
  late SettingsProvider settingsProvider;
  @override
  void initState() {
    super.initState();
    settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _currency = settingsProvider.currency;
    if (widget.task != null) {
      _currency = widget.task!.currency;
      type = widget.task?.type ?? 'newFeature';
      status = widget.task?.status ?? 'toDo';
      startDate = widget.task!.startDate;
      endDate = widget.task!.endDate;
      nameController.text = widget.task!.name;
      detailsController.text = widget.task!.details;
      costController.text = widget.task!.cost.toString();
      estimatedTimeController.text = widget.task!.estimatedTime.toString();
      hourlyRateController.text = widget.task!.hourlyRate == 0
          ? settingsProvider.hourCost.toString()
          : widget.task!.hourlyRate.toString();
      final hours = widget.task!.timeSpentInSeconds ~/ 3600;
      final minutes = (widget.task!.timeSpentInSeconds % 3600) ~/ 60;
      hoursController.text = hours.toString();
      minutesController.text = minutes.toString();
      subTasks = List<Map<String, dynamic>>.from(widget.task!.subTasks);
      isPaid = widget.task!.isPaid;
      selectedPaymentMethodId = widget.task!.paymentMethodId;
      isArchived = widget.task!.isArchived;
      selectedAssigneeIds.addAll(widget.task!.assigneeIds);
      // Initialize expected cost for existing tasks
      final rate = double.tryParse(hourlyRateController.text) ?? 0.0;
      _expectedCost = widget.task!.estimatedTime * rate;

      // Auto-fill cost if it is 0 and we have a calculated expected cost
      if (widget.task!.cost == 0 && _expectedCost > 0) {
        costController.text = _expectedCost.toStringAsFixed(2);
      }
    } else {
      hourlyRateController.text = settingsProvider.hourCost.toString();
    }

    // Add listeners for auto-calculation
    estimatedTimeController.addListener(_updateCost);
    hourlyRateController.addListener(_updateCost);
    hoursController.addListener(_updateCost);
    minutesController.addListener(_updateCost);
  }

  void _updateCost() {
    final rate = double.tryParse(hourlyRateController.text) ?? 0.0;
    final estimatedTime = double.tryParse(estimatedTimeController.text) ?? 0.0;

    final hours = int.tryParse(hoursController.text) ?? 0;
    final minutes = int.tryParse(minutesController.text) ?? 0;
    final recordedTimeInHours = hours + (minutes / 60.0);

    if (rate > 0) {
      double calculated;
      // Prioritize recorded time if it exists (greater than 0)
      if (recordedTimeInHours > 0) {
        calculated = recordedTimeInHours * rate;
      } else {
        calculated = estimatedTime * rate;
      }

      setState(() {
        _expectedCost = calculated;
      });

      // Update the actual cost field if we have a valid rate (Hourly Model)
      costController.text = calculated.toStringAsFixed(2);
    } else {
      setState(() {
        _expectedCost = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _listeningFieldNotifier.dispose();
    estimatedTimeController.removeListener(_updateCost);
    hourlyRateController.removeListener(_updateCost);
    hoursController.removeListener(_updateCost);
    minutesController.removeListener(_updateCost);
    nameController.dispose();
    detailsController.dispose();
    costController.dispose();
    estimatedTimeController.dispose();
    hourlyRateController.dispose();
    hoursController.dispose();
    minutesController.dispose();
    todoController.dispose();
    super.dispose();
  }

  Future<void> _toggleFieldSpeech(
    TextEditingController controller,
    String fieldName,
  ) async {
    final lang = context.locale.languageCode;

    if (_listeningFieldName == fieldName) {
      await _speech.stop();
      _listeningFieldNotifier.value = null;
      return;
    }

    if (_listeningFieldName != null) {
      await _speech.stop();
      _listeningFieldNotifier.value = null;
    }

    if (!_speechInitialized) {
      try {
        _speechInitialized = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              if (mounted && _listeningFieldName == fieldName) {
                _listeningFieldNotifier.value = null;
              }
            }
          },
          onError: (_) {
            _listeningFieldNotifier.value = null;
          },
        );
      } catch (_) {
        _speechInitialized = false;
      }
    }

    if (!_speechInitialized) return;

    _listeningFieldNotifier.value = fieldName;

    final localeId = lang == 'ar' ? 'ar-EG' : 'en-US';

    await _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          controller.text = result.recognizedWords;
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Widget _buildMicSuffix(TextEditingController controller, String fieldName) {
    return ValueListenableBuilder<String?>(
      valueListenable: _listeningFieldNotifier,
      builder: (context, listeningField, _) {
        final isListening = listeningField == fieldName;
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(36, 36),
          onPressed: () => _toggleFieldSpeech(controller, fieldName),
          child: isListening
              ? const Icon(
                      CupertinoIcons.mic_fill,
                      color: CupertinoColors.destructiveRed,
                      size: 18,
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      duration: 400.ms,
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1.15, 1.15),
                    )
              : const Icon(
                  CupertinoIcons.mic,
                  color: CupertinoColors.systemGrey2,
                  size: 18,
                ),
        );
      },
    );
  }

  void _confirmDeleteTask(BuildContext context) {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('deleteTask'.tr()),
        content: Text('deleteTaskConfirm'.tr()),
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
              ).deleteTask(widget.task!.id, widget.projectId);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(
        middle: Text(widget.task == null ? 'addTask'.tr() : 'editTask'.tr()),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text('cancel'.tr()),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.task != null)
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const FaIcon(
                  FontAwesomeIcons.trashCan,
                  color: CupertinoColors.destructiveRed,
                  size: 20,
                ),
                onPressed: () => _confirmDeleteTask(context),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text('save'.tr()),
              onPressed: () async {
                if (nameController.text.isEmpty) return;

                final provider = Provider.of<ProjectProvider>(
                  context,
                  listen: false,
                );

                final hours = int.tryParse(hoursController.text) ?? 0;
                final minutes = int.tryParse(minutesController.text) ?? 0;
                final newTimeSpentSeconds = (hours * 3600) + (minutes * 60);

                bool shouldSave = true;

                if (widget.task != null &&
                    newTimeSpentSeconds != widget.task!.timeSpentInSeconds) {
                  // Show warning
                  final confirmed = await showCupertinoDialog<bool>(
                    useRootNavigator: false,
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: Text('recordedTime'.tr()),
                      content: Text('timeOverrideWarning'.tr()),
                      actions: [
                        CupertinoDialogAction(
                          child: Text('cancel'.tr()),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          child: Text('override'.tr()),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) shouldSave = false;
                }

                if (!shouldSave) return;

                final newTask = ProjectTask(
                  id: widget.task?.id ?? const Uuid().v4(),
                  projectId: widget.projectId,
                  name: nameController.text,
                  details: detailsController.text,
                  attachments: widget.task?.attachments ?? const [],
                  startDate: startDate,
                  endDate: endDate,
                  cost: double.tryParse(costController.text) ?? 0.0,
                  currency: _currency,
                  isCompleted: status == 'done',
                  status: status,
                  type: type,
                  subTasks: subTasks,
                  isPaid: isPaid,
                  paymentMethodId: selectedPaymentMethodId,
                  timeSpentInSeconds: newTimeSpentSeconds,
                  isTimerRunning: widget.task?.isTimerRunning ?? false,
                  lastStartTime: widget.task?.lastStartTime,
                  timerStartAt: widget.task?.timerStartAt,
                  timerEndAt: widget.task?.timerEndAt,
                  estimatedTime:
                      double.tryParse(estimatedTimeController.text) ?? 0.0,
                  hourlyRate: double.tryParse(hourlyRateController.text) ?? 0.0,
                  isArchived: isArchived,
                  assigneeIds: selectedAssigneeIds.toList(),
                );

                if (widget.task == null) {
                  await provider.addTask(newTask);
                } else {
                  await provider.updateTask(newTask);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: StatefulBuilder(
          builder: (context, setState) => AppLayout.constrain(
            ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: _listeningFieldNotifier,
                  builder: (context, listeningField, _) => CupertinoTextField(
                    decoration: AppCard.container(
                      context,
                      radius: AppRadius.md,
                    ),
                    controller: nameController,
                    placeholder: listeningField == 'name'
                        ? 'listening'.tr()
                        : 'taskName'.tr(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    suffix: _buildMicSuffix(nameController, 'name'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ValueListenableBuilder<String?>(
                  valueListenable: _listeningFieldNotifier,
                  builder: (context, listeningField, _) => CupertinoTextField(
                    decoration: AppCard.container(
                      context,
                      radius: AppRadius.md,
                    ),
                    controller: detailsController,
                    placeholder: listeningField == 'details'
                        ? 'listening'.tr()
                        : 'details'.tr(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    maxLines: 3,
                    suffix: _buildMicSuffix(detailsController, 'details'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        decoration: AppCard.container(
                          context,
                          radius: AppRadius.md,
                        ),
                        controller: costController,
                        placeholder: 'cost'.tr(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        prefix: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.sm,
                            right: AppSpacing.sm,
                          ),
                          child: Text(_currency),
                        ),
                      ),
                    ),

                    SizedBox(width: AppSpacing.md),
                    GestureDetector(
                      onTap: () => showCupertinoModalPopup(
                        useRootNavigator: false,
                        context: context,
                        builder: (_) => CupertinoActionSheet(
                          title: Text('selectCurrency'.tr()),
                          actions: settingsProvider.listCurency.map((currency) {
                            return CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() {
                                  _currency = currency;
                                });
                                Navigator.pop(context);
                              },
                              child: Text(currency.tr()),
                            );
                          }).toList(),
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.pop(context),
                            child: Text('cancel'.tr()),
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(left: AppSpacing.sm),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_currency),
                            const FaIcon(
                              FontAwesomeIcons.chevronDown,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Estimated Time Input
                CupertinoTextField(
                  decoration: AppCard.container(context, radius: AppRadius.md),
                  controller: estimatedTimeController,
                  placeholder: 'estimatedTimePlaceholder'.tr(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  suffix: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      'hours'.tr(),
                      style: TextStyle(color: CupertinoColors.systemGrey),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Hourly Rate Input
                CupertinoTextField(
                  decoration: AppCard.container(context, radius: AppRadius.md),
                  controller: hourlyRateController,
                  placeholder: 'hourCost'.tr(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  suffix: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      '/ ${'hours'.tr()}',
                      style: TextStyle(color: CupertinoColors.systemGrey),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Manual Time Spent Entry
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'recordedTime'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            decoration: AppCard.container(
                              context,
                              radius: AppRadius.md,
                            ),
                            controller: hoursController,
                            placeholder: 'hours'.tr(),
                            keyboardType: TextInputType.number,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            suffix: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Text(
                                'hours'.tr(),
                                style: TextStyle(
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: CupertinoTextField(
                            decoration: AppCard.container(
                              context,
                              radius: AppRadius.md,
                            ),
                            controller: minutesController,
                            placeholder: 'minutes'.tr(),
                            keyboardType: TextInputType.number,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            suffix: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Text(
                                'minutes'.tr(),
                                style: TextStyle(
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.task?.timerStartAt != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            Text(
                              '${"timerStart".tr()}: ',
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                                'en',
                              ).format(widget.task!.timerStartAt!),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (widget.task?.timerEndAt != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            children: [
                              Text(
                                '${"timerEnd".tr()}: ',
                                style: const TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                  'en',
                                ).format(widget.task!.timerEndAt!),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                if (_expectedCost > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${"expectedCost".tr()}: ',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${_expectedCost.toStringAsFixed(2)} $_currency',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                // Start Date Picker
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedBackground(context),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('startDate'.tr()),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(
                          DateFormat('yyyy-MM-dd', 'en').format(startDate),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                        onPressed: () {
                          showCupertinoModalPopup(
                            useRootNavigator: false,
                            context: context,
                            builder: (context) => Container(
                              height: 216,
                              padding: const EdgeInsets.only(top: 6.0),
                              margin: EdgeInsets.only(
                                bottom: MediaQuery.viewInsetsOf(context).bottom,
                              ),
                              color: AppColors.cardBackground(context),
                              child: SafeArea(
                                top: false,
                                child: CupertinoDatePicker(
                                  initialDateTime: startDate,
                                  mode: CupertinoDatePickerMode.date,
                                  use24hFormat: true,
                                  onDateTimeChanged: (DateTime newDate) {
                                    setState(() {
                                      startDate = newDate;
                                    });
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // End Date Picker
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedBackground(context),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('endDate'.tr()),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(
                          endDate != null
                              ? DateFormat('yyyy-MM-dd', 'en').format(endDate!)
                              : 'notSet'.tr(),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                        onPressed: () {
                          showCupertinoModalPopup(
                            useRootNavigator: false,
                            context: context,
                            builder: (context) => Container(
                              height: 216,
                              padding: const EdgeInsets.only(top: 6.0),
                              margin: EdgeInsets.only(
                                bottom: MediaQuery.viewInsetsOf(context).bottom,
                              ),
                              color: AppColors.cardBackground(context),
                              child: SafeArea(
                                top: false,
                                child: CupertinoDatePicker(
                                  initialDateTime: endDate ?? startDate,
                                  mode: CupertinoDatePickerMode.date,
                                  use24hFormat: true,
                                  minimumDate: startDate,
                                  onDateTimeChanged: (DateTime newDate) {
                                    setState(() {
                                      endDate = newDate;
                                    });
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('status'.tr()),
                const SizedBox(height: AppSpacing.sm),
                CupertinoSlidingSegmentedControl<String>(
                  backgroundColor: AppColors.elevatedBackground(context),
                  thumbColor: AppColors.cardBackground(context),
                  groupValue: status,
                  children: statusMap.map(
                    (key, value) => MapEntry(
                      key,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(value),
                      ),
                    ),
                  ),
                  onValueChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      status = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('type'.tr()),
                const SizedBox(height: AppSpacing.sm),
                CupertinoSlidingSegmentedControl<String>(
                  backgroundColor: AppColors.elevatedBackground(context),
                  thumbColor: AppColors.cardBackground(context),
                  groupValue: type,
                  children: typeMap.map(
                    (k, value) => MapEntry(
                      k,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(value),
                      ),
                    ),
                  ),
                  onValueChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      type = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('assignees'.tr()),
                const SizedBox(height: AppSpacing.sm),
                Consumer<ProjectProvider>(
                  builder: (context, projectProvider, _) {
                    final members = projectProvider.getMembers(
                      widget.projectId,
                    );
                    if (members.isEmpty) {
                      return Text(
                        'addMembersFirst'.tr(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members.map((m) {
                        final selected = selectedAssigneeIds.contains(m.id);
                        final color = Color(m.color);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                selectedAssigneeIds.remove(m.id);
                              } else {
                                selectedAssigneeIds.add(m.id);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.2)
                                  : AppColors.elevatedBackground(context),
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : AppColors.separator(context),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    m.initials,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                // Payment Section
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedBackground(context),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('isPaid'.tr()),
                          CupertinoSwitch(
                            activeTrackColor: AppColors.primary,
                            value: isPaid,
                            onChanged: (value) {
                              setState(() {
                                isPaid = value;
                              });
                            },
                          ),
                        ],
                      ),
                      if (isPaid) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Divider(height: 1),
                        ),
                        Consumer<WalletProvider>(
                          builder: (context, walletProvider, _) {
                            final method = walletProvider.paymentMethods
                                .where((m) => m.id == selectedPaymentMethodId)
                                .firstOrNull;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('paymentMethod'.tr()),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Text(
                                    method?.name ?? 'select'.tr(),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  onPressed: () {
                                    showCupertinoModalPopup(
                                      useRootNavigator: false,
                                      context: context,
                                      builder: (context) => CupertinoActionSheet(
                                        title: Text('selectPaymentMethod'.tr()),
                                        actions: walletProvider.paymentMethods
                                            .map((m) {
                                              return CupertinoActionSheetAction(
                                                onPressed: () {
                                                  setState(() {
                                                    selectedPaymentMethodId =
                                                        m.id;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: Text(m.name),
                                              );
                                            })
                                            .toList(),
                                        cancelButton:
                                            CupertinoActionSheetAction(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text('cancel'.tr()),
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Todo List Section
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedBackground(context),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'todoList'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const FaIcon(
                                  FontAwesomeIcons.arrowDownShortWide,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    subTasks.sort((a, b) {
                                      if (a['isDone'] == b['isDone']) return 0;
                                      return a['isDone'] ? 1 : -1;
                                    });
                                  });
                                },
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const FaIcon(
                                  FontAwesomeIcons.circlePlus,
                                  size: 20,
                                ),
                                onPressed: () {
                                  if (todoController.text.isNotEmpty) {
                                    setState(() {
                                      subTasks.add({
                                        'title': todoController.text,
                                        'isDone': false,
                                      });
                                      todoController.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: _listeningFieldNotifier,
                        builder: (context, listeningField, _) =>
                            CupertinoTextField(
                              decoration: AppCard.container(
                                context,
                                radius: AppRadius.md,
                              ),
                              controller: todoController,
                              placeholder: listeningField == 'todo'
                                  ? 'listening'.tr()
                                  : 'todoPlaceholder'.tr(),
                              padding: const EdgeInsets.all(10),
                              suffix: _buildMicSuffix(todoController, 'todo'),
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  setState(() {
                                    subTasks.add({
                                      'title': value,
                                      'isDone': false,
                                    });
                                    todoController.clear();
                                  });
                                }
                              },
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (subTasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: Text(
                              'noTasksYet'.tr(),
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        Theme(
                          data:
                              CupertinoTheme.brightnessOf(context) ==
                                  Brightness.dark
                              ? ThemeData.dark().copyWith(
                                  scaffoldBackgroundColor:
                                      AppColors.surfaceDarkAlt,
                                )
                              : ThemeData.light(),
                          child: Material(
                            color: Colors.transparent,
                            child: ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: subTasks.length,
                              onReorderItem: (oldIndex, newIndex) {
                                setState(() {
                                  final item = subTasks.removeAt(oldIndex);
                                  subTasks.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                final todo = subTasks[index];
                                return Container(
                                  key: ObjectKey(todo),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  color: Colors.transparent,
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            subTasks[index]['isDone'] =
                                                !subTasks[index]['isDone'];
                                          });
                                        },
                                        child: FaIcon(
                                          todo['isDone']
                                              ? FontAwesomeIcons
                                                    .solidCircleCheck
                                              : FontAwesomeIcons.circle,
                                          color: todo['isDone']
                                              ? CupertinoColors.activeGreen
                                              : CupertinoColors.systemGrey,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          todo['title'],
                                          style: TextStyle(
                                            decoration: todo['isDone']
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: todo['isDone']
                                                ? CupertinoColors.systemGrey
                                                : null,
                                          ),
                                        ),
                                      ),
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        child: const FaIcon(
                                          FontAwesomeIcons.trashCan,
                                          color: CupertinoColors.systemRed,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            subTasks.removeAt(index);
                                          });
                                        },
                                      ),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Container(
                                          padding: EdgeInsets.only(
                                            left: AppSpacing.sm,
                                          ),
                                          child: const FaIcon(
                                            FontAwesomeIcons.gripLines,
                                            color: CupertinoColors.systemGrey,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
