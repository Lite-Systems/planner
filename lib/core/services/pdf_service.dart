import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/project.dart';
import '../../models/project_task.dart';

class PdfService {
  // ── Cached assets ──────────────────────────────────────────────────────────
  // The Almarai font and the logo are read from the bundle once and reused for
  // every document, instead of being re-loaded on each print/share.
  static ByteData? _fontData;
  static Uint8List? _logoBytes;
  static bool _logoLoaded = false;

  static Future<ByteData> _loadFontData() async {
    return _fontData ??= await rootBundle.load(
      'assets/fonts/Almarai-Regular.ttf',
    );
  }

  static Future<Uint8List?> _loadLogoBytes() async {
    if (!_logoLoaded) {
      _logoLoaded = true;
      try {
        final data = await rootBundle.load('assets/images/logo.png');
        _logoBytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      } catch (_) {
        // Fallback if logo not found.
        _logoBytes = null;
      }
    }
    return _logoBytes;
  }

  Future<void> printProjectInvoice(
    Project project,
    List<ProjectTask> tasks,
    Locale locale, {
    required String currency,
    bool showHourCost = true,
    bool showTaskType = true,
    bool showTaskTime = true,
    bool showSubtasks = true,
    String? documentName,
    void Function(bool generating)? onGenerating,
  }) async {
    final bytes = await _generateBytes(
      project,
      tasks,
      locale,
      currency: currency,
      showHourCost: showHourCost,
      showTaskType: showTaskType,
      showTaskTime: showTaskTime,
      showSubtasks: showSubtasks,
      onGenerating: onGenerating,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: _safeFileName(documentName ?? 'Invoice_${project.name}'),
    );
  }

  Future<void> shareProjectInvoice(
    Project project,
    List<ProjectTask> tasks,
    Locale locale, {
    required String currency,
    bool showHourCost = true,
    bool showTaskType = true,
    bool showTaskTime = true,
    bool showSubtasks = true,
    String? documentName,
    Rect? sharePositionOrigin,
    void Function(bool generating)? onGenerating,
  }) async {
    final bytes = await _generateBytes(
      project,
      tasks,
      locale,
      currency: currency,
      showHourCost: showHourCost,
      showTaskType: showTaskType,
      showTaskTime: showTaskTime,
      showSubtasks: showSubtasks,
      onGenerating: onGenerating,
    );

    final output = await getTemporaryDirectory();
    final prefix = _safeFileName(documentName ?? 'Invoice_${project.name}');
    final fileName = "${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File("${output.path}/$fileName");
    await _writePdf(file, bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'invoiceShareText'.tr(namedArgs: {'name': project.name}),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty
        ? 'invoice'
        : cleaned.substring(0, math.min(cleaned.length, 80));
  }

  Future<void> _writePdf(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  /// Resolves every localized label on the main isolate (where the translation
  /// context lives) so the render isolate only ever sees plain strings.
  Map<String, String> _resolveLabels() => {
    'draft': 'draft'.tr(),
    'projectCustomer': 'projectCustomer'.tr(),
    'createdAt': 'createdAt'.tr(),
    'projectSummary': 'projectSummary'.tr(),
    'status': 'status'.tr(),
    'totalCost': 'totalCost'.tr(),
    'completionRate': 'completionRate'.tr(),
    'tasksCount': 'tasksCount'.tr(),
    'totalPaid': 'totalPaid'.tr(),
    'totalRemaining': 'totalRemaining'.tr(),
    'tasksDetails': 'tasksDetails'.tr(),
    'tasks': 'tasks'.tr(),
    'timeSpent': 'timeSpent'.tr(),
    'startDate': 'startDate'.tr(),
    'endDate': 'endDate'.tr(),
    'timerStart': 'timerStart'.tr(),
    'timerEnd': 'timerEnd'.tr(),
    'subtasksList': 'subtasksList'.tr(),
    'paid': 'paid'.tr(),
    'unpaid': 'unpaid'.tr(),
    'page': 'page'.tr(),
    'of': 'of'.tr(),
  };

  /// Loads the cached assets, packages the request as plain data and renders
  /// the PDF on a background isolate so the UI thread stays responsive.
  Future<Uint8List> _generateBytes(
    Project project,
    List<ProjectTask> tasks,
    Locale locale, {
    required String currency,
    required bool showHourCost,
    required bool showTaskType,
    required bool showTaskTime,
    bool showSubtasks = true,
    bool isDraft = false,
    void Function(bool generating)? onGenerating,
  }) async {
    final fontData = await _loadFontData();
    final logoBytes = await _loadLogoBytes();

    final job = _PdfJob(
      project: project,
      tasks: tasks,
      isArabic: locale.languageCode == 'ar',
      currency: currency,
      showHourCost: showHourCost,
      showTaskType: showTaskType,
      showTaskTime: showTaskTime,
      showSubtasks: showSubtasks,
      isDraft: isDraft,
      labels: _resolveLabels(),
      projectStatusLabel: project.status.tr(),
      taskTypeLabels: {for (final t in tasks) t.type: t.type.tr()},
      fontData: fontData,
      logoBytes: logoBytes,
    );

    onGenerating?.call(true);
    try {
      return await compute(_renderProjectPdf, job);
    } finally {
      onGenerating?.call(false);
    }
  }

  /// Save PDF to a specific file path
  Future<File> saveProjectInvoiceToFile(
    Project project,
    List<ProjectTask> tasks,
    Locale locale,
    String filePath, {
    required String currency,
    bool showHourCost = true,
    bool showTaskType = true,
    bool showTaskTime = true,
    bool showSubtasks = true,
    bool isDraft = false,
    void Function(bool generating)? onGenerating,
  }) async {
    final bytes = await _generateBytes(
      project,
      tasks,
      locale,
      currency: currency,
      showHourCost: showHourCost,
      showTaskType: showTaskType,
      showTaskTime: showTaskTime,
      showSubtasks: showSubtasks,
      isDraft: isDraft,
      onGenerating: onGenerating,
    );

    final file = File(filePath);
    await _writePdf(file, bytes);
    return file;
  }

  /// Preview PDF before printing with custom settings
  Future<void> previewProjectInvoice(
    Project project,
    List<ProjectTask> tasks,
    Locale locale, {
    required String currency,
    bool showHourCost = true,
    bool showTaskType = true,
    bool showTaskTime = true,
    bool showSubtasks = true,
    bool isDraft = false,
    void Function(bool generating)? onGenerating,
  }) async {
    final bytes = await _generateBytes(
      project,
      tasks,
      locale,
      currency: currency,
      showHourCost: showHourCost,
      showTaskType: showTaskType,
      showTaskTime: showTaskTime,
      showSubtasks: showSubtasks,
      isDraft: isDraft,
      onGenerating: onGenerating,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Invoice_${project.name}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  /// Get PDF bytes for custom handling
  Future<List<int>> getProjectInvoiceBytes(
    Project project,
    List<ProjectTask> tasks,
    Locale locale, {
    required String currency,
    bool showHourCost = true,
    bool showTaskType = true,
    bool showTaskTime = true,
    bool showSubtasks = true,
    bool isDraft = false,
    void Function(bool generating)? onGenerating,
  }) {
    return _generateBytes(
      project,
      tasks,
      locale,
      currency: currency,
      showHourCost: showHourCost,
      showTaskType: showTaskType,
      showTaskTime: showTaskTime,
      showSubtasks: showSubtasks,
      isDraft: isDraft,
      onGenerating: onGenerating,
    );
  }
}

// ── Isolate-side rendering ────────────────────────────────────────────────────
// Everything below runs in the background isolate: it only touches plain data
// (models + strings + cached byte arrays) and never `rootBundle`/`BuildContext`.

/// Plain request payload for [_renderProjectPdf].
class _PdfJob {
  const _PdfJob({
    required this.project,
    required this.tasks,
    required this.isArabic,
    required this.currency,
    required this.showHourCost,
    required this.showTaskType,
    required this.showTaskTime,
    required this.showSubtasks,
    required this.isDraft,
    required this.labels,
    required this.projectStatusLabel,
    required this.taskTypeLabels,
    required this.fontData,
    required this.logoBytes,
  });

  final Project project;
  final List<ProjectTask> tasks;
  final bool isArabic;
  final String currency;
  final bool showHourCost;
  final bool showTaskType;
  final bool showTaskTime;
  final bool showSubtasks;
  final bool isDraft;
  final Map<String, String> labels;
  final String projectStatusLabel;
  final Map<String, String> taskTypeLabels;
  final ByteData fontData;
  final Uint8List? logoBytes;

  String label(String key) => labels[key] ?? key;
}

Future<Uint8List> _renderProjectPdf(_PdfJob job) async {
  final pdf = pw.Document();
  final arabicFont = pw.Font.ttf(job.fontData);
  final isArabic = job.isArabic;

  // Create a theme that supports Arabic globally
  final theme = pw.ThemeData.withFont(
    base: arabicFont,
    bold: arabicFont, // Using same font if bold version not found
    italic: arabicFont,
  );

  // Load logo
  pw.MemoryImage? logoImage;
  if (job.logoBytes != null) {
    logoImage = pw.MemoryImage(job.logoBytes!);
  }

  pdf.addPage(
    pw.MultiPage(
      theme: theme,
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      pageFormat: PdfPageFormat.a4,
      // Optimized margins for printing (20mm on all sides)
      margin: const pw.EdgeInsets.all(56.69), // 20mm in points
      header: (context) => _buildHeader(job, logoImage, isArabic),
      footer: (context) => _buildFooter(context, job, isArabic),
      build: (context) => [
        // Add watermark for draft versions
        if (job.isDraft) _buildWatermark(job, isArabic),
        pw.SizedBox(height: 10),
        _buildProjectSummary(job, isArabic),
        pw.SizedBox(height: 20),
        _buildTaskDetailsSection(job, isArabic),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _buildWatermark(_PdfJob job, bool isArabic) {
  return pw.Transform.rotate(
    angle: -0.5, // Diagonal watermark
    child: pw.Center(
      child: pw.Opacity(
        opacity: 0.1,
        child: pw.Text(
          job.label('draft'),
          style: pw.TextStyle(
            fontSize: 80,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey,
          ),
        ),
      ),
    ),
  );
}

pw.Widget _buildHeader(
  _PdfJob job,
  pw.MemoryImage? logoImage,
  bool isArabic,
) {
  final project = job.project;
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF08010), width: 2),
      ),
    ),
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo section
            if (logoImage != null)
              pw.Container(height: 50, width: 50, child: pw.Image(logoImage)),
            // Project info section
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    project.name,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFFF08010),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (project.customer != null &&
                      project.customer!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${job.label('projectCustomer')}: ${project.customer}',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey800,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                  pw.SizedBox(height: 4),
                  pw.Text(
                    project.description,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                    textAlign: pw.TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            // Date section
            pw.Container(
              width: 100,
              child: pw.Column(
                crossAxisAlignment: isArabic
                    ? pw.CrossAxisAlignment.start
                    : pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    job.label('createdAt'),
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildProjectSummary(_PdfJob job, bool isArabic) {
  final tasks = job.tasks;
  final currency = job.currency;
  final totalCost = tasks.fold(0.0, (sum, t) => sum + t.cost);
  final totalPaid = tasks
      .where((t) => t.isPaid)
      .fold(0.0, (sum, t) => sum + t.cost);
  final totalRemaining = totalCost - totalPaid;
  final completedTasks = tasks.where((t) => t.isCompleted).length;
  final completionRate = tasks.isEmpty
      ? 0.0
      : (completedTasks / tasks.length) * 100;

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 1),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    padding: const pw.EdgeInsets.all(12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 18,
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF08010),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              job.label('projectSummary'),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFFF08010),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        // Main info table - using print-friendly colors
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(
                  0xFFE3F2FD,
                ), // Light blue for printing
              ),
              children: isArabic
                  ? [
                      _buildSummaryHeaderCell(job.label('status')),
                      _buildSummaryHeaderCell(job.label('totalCost')),
                      _buildSummaryHeaderCell(job.label('completionRate')),
                      _buildSummaryHeaderCell(job.label('tasksCount')),
                    ]
                  : [
                      _buildSummaryHeaderCell(job.label('tasksCount')),
                      _buildSummaryHeaderCell(job.label('completionRate')),
                      _buildSummaryHeaderCell(job.label('totalCost')),
                      _buildSummaryHeaderCell(job.label('status')),
                    ],
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.white),
              children: isArabic
                  ? [
                      _buildSummaryDataCell(job.projectStatusLabel),
                      _buildSummaryDataCell(
                        '$currency ${totalCost.toStringAsFixed(2)}',
                      ),
                      _buildSummaryDataCell(
                        '${completionRate.toStringAsFixed(1)}%',
                      ),
                      _buildSummaryDataCell(tasks.length.toString()),
                    ]
                  : [
                      _buildSummaryDataCell(tasks.length.toString()),
                      _buildSummaryDataCell(
                        '${completionRate.toStringAsFixed(1)}%',
                      ),
                      _buildSummaryDataCell(
                        '$currency ${totalCost.toStringAsFixed(2)}',
                      ),
                      _buildSummaryDataCell(job.projectStatusLabel),
                    ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        // Payment info table - using print-friendly colors
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(
                  0xFFE8F5E9,
                ), // Light green for printing
              ),
              children: isArabic
                  ? [
                      _buildSummaryHeaderCell(job.label('totalPaid')),
                      _buildSummaryHeaderCell(job.label('totalRemaining')),
                    ]
                  : [
                      _buildSummaryHeaderCell(job.label('totalRemaining')),
                      _buildSummaryHeaderCell(job.label('totalPaid')),
                    ],
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.white),
              children: isArabic
                  ? [
                      _buildSummaryDataCell(
                        '$currency ${totalPaid.toStringAsFixed(2)}',
                      ),
                      _buildSummaryDataCell(
                        '$currency ${totalRemaining.toStringAsFixed(2)}',
                      ),
                    ]
                  : [
                      _buildSummaryDataCell(
                        '$currency ${totalRemaining.toStringAsFixed(2)}',
                      ),
                      _buildSummaryDataCell(
                        '$currency ${totalPaid.toStringAsFixed(2)}',
                      ),
                    ],
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildSummaryHeaderCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.grey800,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    ),
  );
}

pw.Widget _buildSummaryDataCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    ),
  );
}

pw.Widget _buildTaskDetailsSection(_PdfJob job, bool isArabic) {
  final tasks = job.tasks;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          pw.Container(
            width: 4,
            height: 18,
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF08010),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            job.label('tasksDetails'),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFFF08010),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              '${tasks.length} ${job.label('tasks')}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      ...tasks.map((task) => _buildTaskCard(job, task, isArabic)),
    ],
  );
}

pw.Widget _buildTaskCard(_PdfJob job, ProjectTask task, bool isArabic) {
  final currency = job.currency;
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 15),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 1),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              task.name,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (job.showHourCost)
              _buildPriceLabel(task.cost, currency, task.isPaid),
          ],
        ),
        pw.SizedBox(height: 4),
        if (job.showTaskType)
          pw.Row(
            children: [
              _buildPaymentStatus(job, task.isPaid),
              pw.SizedBox(width: 4),
              _buildTaskBadge(job, task.type),
            ],
          ),
        if (job.showTaskTime) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            '${job.label('timeSpent')}: ${_formatSeconds(task.timeSpentInSeconds)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
          ),
        ],
        pw.SizedBox(height: 4),
        pw.Text(
          task.details,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        if (job.showTaskTime)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${job.label('startDate')}: ${DateFormat('yyyy-MM-dd').format(task.startDate)} ${task.endDate != null ? ' - ${job.label('endDate')}: ${DateFormat('yyyy-MM-dd').format(task.endDate!)}' : ''}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              if (task.timerStartAt != null)
                pw.Text(
                  '${job.label('timerStart')}: ${DateFormat('yyyy-MM-dd HH:mm').format(task.timerStartAt!)} ${task.timerEndAt != null ? ' - ${job.label('timerEnd')}: ${DateFormat('yyyy-MM-dd HH:mm').format(task.timerEndAt!)}' : ''}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
            ],
          ),
        if (job.showSubtasks && task.subTasks.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 5),
          pw.Text(
            '${job.label('subtasksList')} (${task.subTasks.where((s) => s['isDone'] == true || s['isDone'] == 1).length}/${task.subTasks.length})',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          ...task.subTasks.map((st) => _buildSubtaskItem(st, isArabic)),
        ],
      ],
    ),
  );
}

pw.Widget _buildPriceLabel(double amount, String currency, bool isPaid) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: pw.BoxDecoration(
          color: isPaid ? PdfColors.green100 : PdfColors.orange100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(
            color: isPaid ? PdfColors.green700 : PdfColors.orange700,
            width: 0.5,
          ),
        ),
        child: pw.Text(
          '$amount $currency',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: isPaid ? PdfColors.green700 : PdfColors.orange700,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _buildSubtaskCheck(bool isDone) {
  return pw.Container(
    width: 7,
    height: 7,
    margin: const pw.EdgeInsets.symmetric(horizontal: 4),
    decoration: pw.BoxDecoration(
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
      border: pw.Border.all(
        color: isDone ? PdfColors.green700 : PdfColors.grey400,
        width: 0.5,
      ),
      color: isDone ? PdfColors.green700 : null,
    ),
    child: isDone
        ? pw.Center(
            child: pw.Text(
              'v',
              style: pw.TextStyle(
                fontSize: 5,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          )
        : null,
  );
}

pw.Widget _buildPaymentStatus(_PdfJob job, bool isPaid) {
  final color = isPaid ? PdfColors.green700 : PdfColors.red700;
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: pw.BoxDecoration(
      color: isPaid ? PdfColors.green50 : PdfColors.red50,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Text(
      job.label(isPaid ? 'paid' : 'unpaid'),
      style: pw.TextStyle(
        fontSize: 7,
        color: color,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _buildFooter(pw.Context context, _PdfJob job, bool isArabic) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColor.fromInt(0xFFF08010), width: 1.5),
      ),
    ),
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Left side - Generated info
            pw.Column(
              crossAxisAlignment: isArabic
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Generated by Smart Planner',
                  style: pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(
                    color: PdfColors.grey500,
                    fontSize: 6,
                  ),
                ),
              ],
            ),
            // Center - Page number
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF08010),
                borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(3),
                ),
              ),
              child: pw.Text(
                '${job.label('page')} ${context.pageNumber} ${job.label('of')} ${context.pagesCount}',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ),
            // Right side - Contact info placeholder
            pw.Column(
              crossAxisAlignment: isArabic
                  ? pw.CrossAxisAlignment.start
                  : pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Smart Planner',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 7,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'smartplanner.app',
                  style: const pw.TextStyle(
                    color: PdfColors.grey500,
                    fontSize: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildTaskBadge(_PdfJob job, String type) {
  PdfColor color;
  switch (type) {
    case 'bug':
      color = PdfColors.red700;
      break;
    case 'enhancement':
      color = PdfColors.blue700;
      break;
    default:
      color = PdfColors.orange700;
  }

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      border: pw.Border.all(color: color, width: 0.5),
    ),
    child: pw.Text(
      job.taskTypeLabels[type] ?? type,
      style: pw.TextStyle(
        fontSize: 8,
        color: color,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _buildSubtaskItem(Map<String, dynamic> subtask, bool isArabic) {
  final isDone = subtask['isDone'] == true || subtask['isDone'] == 1;
  final title = subtask['title']?.toString() ?? '';

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        if (!isArabic) _buildSubtaskCheck(isDone),
        pw.Expanded(
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              color: isDone ? PdfColors.grey600 : PdfColors.black,
              decoration: isDone ? pw.TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (isArabic) _buildSubtaskCheck(isDone),
      ],
    ),
  );
}

String _formatSeconds(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else if (minutes > 0) {
    return '${minutes}m ${secs}s';
  } else {
    return '${secs}s';
  }
}
