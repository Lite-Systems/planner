import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, Icons, Material, Theme, ThemeData;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../../../../models/project_task.dart';
import '../../../../providers/project_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../core/utils/app_layout.dart';
import '../../../core/utils/speech_parser.dart';

class VoiceTaskSheet extends StatefulWidget {
  final String projectId;

  const VoiceTaskSheet({super.key, required this.projectId});

  @override
  State<VoiceTaskSheet> createState() => _VoiceTaskSheetState();
}

class _VoiceTaskSheetState extends State<VoiceTaskSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  String _wordsSpoken = "";

  final TextEditingController _taskNameController = TextEditingController();
  final List<String> _subtasks = [];
  final TextEditingController _newSubtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _taskNameController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  /// Initialize speech recognition
  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          setState(() {
            _isListening = false;
          });
        },
      );
      if (_speechEnabled) {
        _startListening();
      }
    } catch (e) {
      setState(() {
        _speechEnabled = false;
      });
    }
  }

  /// Start speech listening
  void _startListening() async {
    if (!_speechEnabled) return;
    _wordsSpoken = "";
    setState(() {
      _isListening = true;
    });

    final locale = context.locale.languageCode; // 'ar' or 'en'
    final localeId = locale == 'ar' ? 'ar-EG' : 'en-US';

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _wordsSpoken = result.recognizedWords;
          if (_wordsSpoken.isNotEmpty) {
            _parseWords(_wordsSpoken);
          }
        });
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 4),
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  /// Stop speech listening
  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  /// Parse the recognized words and populate task & subtasks
  void _parseWords(String speechText) {
    final parsed = SpeechParser.parse(speechText);
    _taskNameController.text = parsed['taskName'] ?? '';

    final List<dynamic> parsedSubs = parsed['subtasks'] ?? [];
    _subtasks.clear();
    for (final sub in parsedSubs) {
      if (sub.toString().isNotEmpty) {
        _subtasks.add(sub.toString());
      }
    }
  }

  /// Save task and subtasks
  void _saveTask() {
    final taskName = _taskNameController.text.trim();
    if (taskName.isEmpty) return;

    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    // Map subtasks to DB format: List<Map<String, dynamic>>
    final formattedSubtasks = _subtasks
        .map((title) => {'title': title, 'isDone': false})
        .toList();

    final newTask = ProjectTask(
      id: const Uuid().v4(),
      projectId: widget.projectId,
      name: taskName,
      details: _wordsSpoken.isNotEmpty ? 'Spoken input: "$_wordsSpoken"' : '',
      startDate: DateTime.now(),
      currency: settingsProvider.currency,
      subTasks: formattedSubtasks,
      status: 'toDo',
      type: 'newFeature',
      attachments: const [],
      cost: 0.0,
    );

    projectProvider.addTask(newTask);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return AppLayout.sheet(
      context,
      Container(
        height: MediaQuery.sizeOf(context).height * 0.85,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : CupertinoColors.secondarySystemBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                // ── Drag Handle ──────────────────────────────────────────
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  key: const ValueKey('header'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: Text('cancel'.tr()),
                      ),
                      Text(
                        'voiceSheetTitle'.tr(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _taskNameController,
                        builder: (context, value, _) {
                          final canSave = value.text.trim().isNotEmpty;
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: canSave ? _saveTask : null,
                            child: Text(
                              'save'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 0.8,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    children: [
                      // ── Visual Sound Wave / Mic Button ──────────────────────
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_isListening) {
                                  _stopListening();
                                } else {
                                  _startListening();
                                }
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Pulsing mic background rings
                                  if (_isListening)
                                    ...List.generate(3, (index) {
                                      return Container(
                                            width: 80 + (index * 24),
                                            height: 80 + (index * 24),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: primaryColor.withValues(
                                                alpha: 0.08 - (index * 0.02),
                                              ),
                                            ),
                                          )
                                          .animate(
                                            onPlay: (c) =>
                                                c.repeat(reverse: true),
                                          )
                                          .scale(
                                            duration: (800 + index * 200).ms,
                                            begin: const Offset(0.9, 0.9),
                                            end: const Offset(1.15, 1.15),
                                            curve: Curves.easeInOut,
                                          );
                                    }),
                                  // Main mic button
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: _isListening
                                            ? [
                                                const Color(0xFF8B5CF6),
                                                const Color(0xFFEC4899),
                                              ]
                                            : [
                                                primaryColor,
                                                primaryColor.withValues(
                                                  alpha: 0.85,
                                                ),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (_isListening
                                                      ? const Color(0xFFEC4899)
                                                      : primaryColor)
                                                  .withValues(alpha: 0.35),
                                          blurRadius: 14,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isListening ? Icons.mic : Icons.mic_none,
                                      color: CupertinoColors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isListening
                                  ? 'listening'.tr()
                                  : 'Tap mic to speak',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isListening
                                    ? const Color(0xFFEC4899)
                                    : CupertinoColors.systemGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isListening)
                              _buildWaveform()
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  'speechTip'.tr(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: CupertinoColors.systemGrey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Realtime speech text area ─────────────────────────────
                      if (_wordsSpoken.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : CupertinoColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '"$_wordsSpoken"',
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ).animate().fadeIn(duration: 300.ms),

                      const SizedBox(height: 20),

                      // ── Parsed Result Preview Card ────────────────────────────
                      Text(
                        'voiceParsingPreview'.tr().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemGrey,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : CupertinoColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CupertinoColors.separator.resolveFrom(
                              context,
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Task Name Input
                            Text(
                              'taskNamePlaceholder'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            CupertinoTextField(
                              controller: _taskNameController,
                              placeholder: 'taskNamePlaceholder'.tr(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1C1C1E)
                                    : CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Subtasks list header
                            const Row(
                              children: [
                                Icon(
                                  CupertinoIcons.list_bullet,
                                  size: 14,
                                  color: CupertinoColors.systemGrey,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Subtasks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Subtasks list items
                            if (_subtasks.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  'noTasksYet'.tr(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.systemGrey2,
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _subtasks.length,
                                itemBuilder: (context, idx) {
                                  return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1C1C1E)
                                              : CupertinoColors.systemGrey6,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              CupertinoIcons.circle,
                                              size: 14,
                                              color: CupertinoColors.systemGrey,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _subtasks[idx],
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(24, 24),
                                              onPressed: () {
                                                setState(() {
                                                  _subtasks.removeAt(idx);
                                                });
                                              },
                                              child: const Icon(
                                                CupertinoIcons
                                                    .xmark_circle_fill,
                                                size: 16,
                                                color:
                                                    CupertinoColors.systemGrey3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(duration: 200.ms)
                                      .slideY(begin: 0.1, end: 0);
                                },
                              ),

                            const SizedBox(height: 10),

                            // Quick subtask entry row
                            Row(
                              children: [
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: _newSubtaskController,
                                    placeholder: 'subtaskNamePlaceholder'.tr(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C1C1E)
                                          : CupertinoColors.systemGrey6,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    onSubmitted: (val) {
                                      _addSubtask();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(36, 36),
                                  onPressed: _addSubtask,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.plus,
                                      color: primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Permission/Initialization error warning
                      if (!_speechEnabled && !_isListening)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.destructiveRed.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: CupertinoColors.destructiveRed
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  color: CupertinoColors.destructiveRed,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'permissionDenied'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.destructiveRed,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(24, 24),
                                  onPressed: _initSpeech,
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
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
          ),
        ),
      ),
    );
  }

  /// Add a subtask manually
  void _addSubtask() {
    final val = _newSubtaskController.text.trim();
    if (val.isNotEmpty) {
      setState(() {
        _subtasks.add(val);
        _newSubtaskController.clear();
      });
    }
  }

  /// Builds a beautiful pulsing equalizer animation row
  Widget _buildWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (index) {
        return Container(
              width: 4,
              height: 12 + (index % 3 == 0 ? 12 : 6),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899),
                borderRadius: BorderRadius.circular(2),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleY(
              duration: (350 + (index * 70)).ms,
              begin: 0.3,
              end: 1.5,
              curve: Curves.easeInOut,
            );
      }),
    );
  }
}
