import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../models/sticky_note.dart';
import '../../../providers/sticky_notes_provider.dart';
import 'dashboard_style.dart';

/// "Sticky notes" block for the home dashboard.
///
/// Renders the saved notes as a responsive paper board plus an add tile;
/// everything persists through [StickyNotesProvider] (local SQLite).
class StickyNotesSection extends StatelessWidget {
  const StickyNotesSection({super.key});

  @override
  Widget build(BuildContext context) =>
      Consumer<StickyNotesProvider>(
        builder: (context, notes, _) => LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cols = width < 560
                ? 2
                : width < 860
                ? 3
                : width < 1160
                ? 4
                : 5;
            const gap = 12.0;
            final itemWidth =
                ((width - gap * (cols - 1)) / cols).clamp(150.0, 280.0);
            final itemHeight = (itemWidth * 0.68).clamp(158.0, 204.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(count: notes.notes.length),
                const SizedBox(height: 12),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  alignment: WrapAlignment.start,
                  children: [
                    for (final (index, note) in notes.notes.indexed)
                      _StickyNoteTile(
                        key: ValueKey(note.id),
                        note: note,
                        width: itemWidth,
                        height: itemHeight,
                        angle: const [-0.012, 0.009, -0.007, 0.014][index % 4],
                      ).animate(
                        delay: Duration(milliseconds: 30 + index * 45),
                      ).fadeIn(duration: 340.ms).moveY(
                        begin: 14,
                        end: 0,
                        duration: 340.ms,
                        curve: Curves.easeOut,
                      ),
                    _AddNoteTile(
                      width: itemWidth,
                      height: itemHeight,
                      showHint: notes.notes.isEmpty,
                    ).animate(
                      delay: Duration(milliseconds: 30 + notes.notes.length * 45),
                    ).fadeIn(duration: 340.ms).moveY(
                      begin: 14,
                      end: 0,
                      duration: 340.ms,
                      curve: Curves.easeOut,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

  static void openEditor(BuildContext context, {StickyNote? note}) {
    showCupertinoModalPopup(
      context: context,
      barrierColor: DashboardStyle.dark(context)
          ? const Color(0xB3000000)
          : const Color(0xB31C1917),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _NoteEditorSheet(
          note: note,
          provider: context.read<StickyNotesProvider>(),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'stickyNotes'.tr(),
          style: DashboardStyle.text(
            context,
            size: 15,
            weight: FontWeight.w700,
          ),
        ),
      ),
      if (count > 0) ...[
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: DashboardStyle.emerald.withValues(alpha: 0.08),
            border: Border.all(
              color: DashboardStyle.emerald.withValues(alpha: 0.25),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: DashboardStyle.text(
              context,
              size: 11,
              weight: FontWeight.w700,
              color: DashboardStyle.emerald,
            ),
          ),
        ),
      ],
    ],
  );
}

class _StickyNoteTile extends StatelessWidget {
  const _StickyNoteTile({
    super.key,
    required this.note,
    required this.width,
    required this.height,
    required this.angle,
  });

  final StickyNote note;
  final double width;
  final double height;
  final double angle;

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('stickyDeleteConfirmTitle'.tr()),
        content: Text('stickyDeleteConfirmBody'.tr()),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: Navigator.of(dialogContext).pop,
            child: Text('cancel'.tr()),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<StickyNotesProvider>().delete(note.id);
            },
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = DashboardStyle.dark(context);
    final palette = StickyNotePalette.colors[note.colorIndex
        .clamp(0, StickyNotePalette.colors.length - 1)];
    final paper = dark ? palette.darkPaper : palette.base;
    final ink = dark ? palette.darkInk : palette.ink;
    final maxLines = height >= 190
        ? 8
        : height >= 173
        ? 7
        : 6;
    final now = DateTime.now();
    final updatedLabel =
        note.updatedAt.day == now.day &&
            note.updatedAt.month == now.month &&
            note.updatedAt.year == now.year
        ? DateFormat('HH:mm').format(note.updatedAt)
        : DateFormat.MMMd(context.locale.toString()).format(note.updatedAt);

    return Transform.rotate(
      angle: angle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => StickyNotesSection.openEditor(context, note: note),
            child: Container(
              width: width,
              height: height,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: dark
                        ? CupertinoColors.black.withValues(alpha: 0.30)
                        : paper.withValues(alpha: 0.55),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.content,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardStyle.text(
                        context,
                        size: 12.5,
                        weight: FontWeight.w500,
                        color: ink,
                      ).copyWith(height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.pencil,
                        size: 11,
                        color: ink.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          updatedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DashboardStyle.text(
                            context,
                            size: 10,
                            weight: FontWeight.w600,
                            color: ink.withValues(alpha: 0.60),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            CupertinoIcons.delete,
                            size: 15,
                            color: ink.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -7,
            left: width / 2 - 24,
            width: 48,
            height: 14,
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                decoration: BoxDecoration(
                  color: dark
                      ? CupertinoColors.white.withValues(alpha: 0.16)
                      : CupertinoColors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddNoteTile extends StatelessWidget {
  const _AddNoteTile({
    required this.width,
    required this.height,
    required this.showHint,
  });

  final double width;
  final double height;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final dashColor = DashboardStyle.muted(context).withValues(alpha: 0.65);
    return GestureDetector(
      onTap: () => StickyNotesSection.openEditor(context),
      child: CustomPaint(
        painter: _DashedRRectPainter(color: dashColor),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DashboardStyle.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: DashboardStyle.orange.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.add,
                  size: 21,
                  color: DashboardStyle.orange,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'stickyAddNote'.tr(),
                style: DashboardStyle.text(
                  context,
                  size: 12,
                  weight: FontWeight.w700,
                  color: DashboardStyle.orange,
                ),
              ),
              if (showHint) ...[
                const SizedBox(height: 4),
                Text(
                  'stickyEmptyHint'.tr(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardStyle.text(
                    context,
                    size: 10,
                    color: DashboardStyle.muted(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
        const Radius.circular(16),
      ),
    );
    const dash = 7.0;
    const gap = 5.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final span = math.min(dash, metric.length - distance);
        canvas.drawPath(
          metric.extractPath(distance, distance + span),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({required this.provider, this.note});

  final StickyNotesProvider provider;
  final StickyNote? note;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.note?.content ?? '',
  )..addListener(_handleTextChanged);
  late int _colorIndex = widget.note?.colorIndex ??
      widget.provider.notes.length % StickyNotePalette.colors.length;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  void _save() {
    final content = _textController.text.trim();
    if (content.isEmpty) return;
    final note = widget.note;
    if (note != null &&
        note.content == content &&
        note.colorIndex == _colorIndex) {
      Navigator.of(context).pop();
      return;
    }
    widget.provider.save(
      StickyNote(
        id: note?.id ?? '',
        content: content,
        colorIndex: _colorIndex,
        createdAt: note?.createdAt ?? DateTime.now(),
        updatedAt: note?.updatedAt ?? DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    final note = widget.note;
    if (note == null) return;
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('stickyDeleteConfirmTitle'.tr()),
        content: Text('stickyDeleteConfirmBody'.tr()),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: Navigator.of(dialogContext).pop,
            child: Text('cancel'.tr()),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.provider.delete(note.id);
              Navigator.of(context).pop();
            },
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.note != null;
    final dark = DashboardStyle.dark(context);
    final canSave = _textController.text.trim().isNotEmpty &&
        (widget.note == null ||
            widget.note!.content != _textController.text.trim() ||
            widget.note!.colorIndex != _colorIndex);

    return Container(
      decoration: BoxDecoration(
        color: DashboardStyle.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: DashboardStyle.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (editing ? 'stickyEdit' : 'stickyNew').tr(),
                      style: DashboardStyle.text(
                        context,
                        size: 16,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(30, 30),
                    onPressed: Navigator.of(context).pop,
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 16,
                      color: DashboardStyle.muted(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: _textController,
                minLines: 5,
                maxLines: 5,
                autofocus: !editing,
                textCapitalization: TextCapitalization.sentences,
                placeholder: 'stickyHint'.tr(),
                padding: const EdgeInsets.all(14),
                maxLength: 1000,
                style: DashboardStyle.text(context, size: 13),
                cursorColor: DashboardStyle.orange,
                decoration: BoxDecoration(
                  color: DashboardStyle.elevated(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DashboardStyle.border(context)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < StickyNotePalette.colors.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: GestureDetector(
                        onTap: () => setState(() => _colorIndex = i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _colorIndex == i
                                  ? StickyNotePalette.colors[i].base
                                  : CupertinoColors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              color: dark
                                  ? StickyNotePalette.colors[i].darkPaper
                                  : StickyNotePalette.colors[i].base,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: CupertinoColors.black.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      onPressed: canSave ? _save : null,
                      child: Text(
                        'save'.tr(),
                        style: DashboardStyle.text(
                          context,
                          size: 13,
                          weight: FontWeight.w700,
                          color: canSave
                              ? CupertinoColors.white
                              : DashboardStyle.muted(context),
                        ),
                      ),
                    ),
                  ),
                  if (editing) ...[
                    const SizedBox(width: 12),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                      onPressed: _confirmDelete,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: CupertinoColors.destructiveRed.withValues(
                            alpha: 0.10,
                          ),
                          border: Border.all(
                            color: CupertinoColors.destructiveRed.withValues(
                              alpha: 0.30,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          CupertinoIcons.delete,
                          size: 20,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
