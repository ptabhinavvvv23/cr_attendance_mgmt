import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/attendance_session_model.dart';
import '../../models/attendance_stats_models.dart';
import '../../models/owner_model.dart';
import 'attendance_csv_exporter.dart';
import 'attendance_excel_exporter.dart';
import 'attendance_pdf_exporter.dart';

/// Available file export formats for Attendance Reports.
enum ExportFormat {
  pdf(
    'PDF Document (.pdf)',
    'pdf',
    'application/pdf',
    Icons.picture_as_pdf_outlined,
  ),
  excel(
    'Excel Workbook (.xlsx)',
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    Icons.table_chart_outlined,
  ),
  csv('CSV Spreadsheet (.csv)', 'csv', 'text/csv', Icons.description_outlined);

  final String label;
  final String extension;
  final String mimeType;
  final IconData icon;

  const ExportFormat(this.label, this.extension, this.mimeType, this.icon);
}

/// Result container returned after an export operation completes.
class ExportResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;
  final ExportFormat format;

  const ExportResult({
    required this.success,
    this.filePath,
    this.errorMessage,
    required this.format,
  });

  factory ExportResult.successful(String path, ExportFormat format) =>
      ExportResult(success: true, filePath: path, format: format);

  factory ExportResult.failure(String message, ExportFormat format) =>
      ExportResult(success: false, errorMessage: message, format: format);
}

/// Central coordinator service managing file generation, local caching,
/// and system sharing via Android/iOS Share Sheets without broad storage permissions.
class AttendanceExportService {
  final AttendanceCsvExporter csvExporter;
  final AttendanceExcelExporter excelExporter;
  final AttendancePdfExporter pdfExporter;

  const AttendanceExportService({
    this.csvExporter = const AttendanceCsvExporter(),
    this.excelExporter = const AttendanceExcelExporter(),
    this.pdfExporter = const AttendancePdfExporter(),
  });

  /// Generates the requested export file, saves it to the temporary app storage,
  /// and prompts the OS share sheet to allow the user to save or send the document.
  Future<ExportResult> exportAndShare({
    required ExportFormat format,
    required ClassAttendanceReport report,
    OwnerModel? owner,
  }) async {
    try {
      final fileName = _generateFileName(report, format);
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/$fileName');

      List<int> bytes;
      switch (format) {
        case ExportFormat.csv:
          bytes = csvExporter.generateReportCsv(report: report, owner: owner);
          break;
        case ExportFormat.excel:
          bytes = excelExporter.generateWorkbook(report: report, owner: owner);
          break;
        case ExportFormat.pdf:
          bytes = await pdfExporter.generatePdf(report: report, owner: owner);
          break;
      }

      if (bytes.isEmpty) {
        return ExportResult.failure(
          'Failed to generate $format file: Generated content is empty.',
          format,
        );
      }

      await targetFile.writeAsBytes(bytes, flush: true);

      final xFile = XFile(
        targetFile.path,
        mimeType: format.mimeType,
        name: fileName,
      );

      final shareSubject =
          'Attendance Report — ${report.classModel?.name ?? 'Class'}';
      final shareText =
          'Attendance Report for ${report.classModel?.name ?? 'Class'} (Section ${report.classModel?.section ?? ''}).';

      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], subject: shareSubject, text: shareText);

      return ExportResult.successful(targetFile.path, format);
    } catch (e) {
      return ExportResult.failure('Export error: $e', format);
    }
  }

  /// Constructs a clean, sanitized, timestamped filename.
  String _generateFileName(ClassAttendanceReport report, ExportFormat format) {
    final className = report.classModel?.name ?? 'Class';
    final section = report.classModel?.section ?? '';
    final sanitizedClass = '${className}_Sec$section'.replaceAll(
      RegExp(r'[^a-zA-Z0-9_\-]'),
      '_',
    );

    final dateStr = AttendanceSessionModel.formatDate(DateTime.now());
    return 'Attendance_${sanitizedClass}_$dateStr.${format.extension}';
  }
}
