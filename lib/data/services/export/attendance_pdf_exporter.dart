import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/attendance_session_model.dart';
import '../../models/attendance_stats_models.dart';
import '../../models/owner_model.dart';

/// Service responsible for rendering clean, multi-page printable PDF documents
/// for attendance registers, student breakdowns, and subject summaries.
class AttendancePdfExporter {
  const AttendancePdfExporter();

  /// Generates a printable A4 PDF document bytes for a [ClassAttendanceReport].
  Future<Uint8List> generatePdf({
    required ClassAttendanceReport report,
    OwnerModel? owner,
  }) async {
    final pdf = pw.Document();

    final className = report.classModel != null
        ? '${report.classModel!.name} — Section ${report.classModel!.section}'
        : 'Class ID: ${report.classId}';
    final academicPeriod =
        '${report.classModel?.academicYear ?? ''}${report.classModel?.semester != null ? ' • ${report.classModel!.semester}' : ''}';
    final crName = owner != null
        ? (owner.displayName != null && owner.displayName!.isNotEmpty
              ? '${owner.displayName} (${owner.registrationNumber})'
              : owner.registrationNumber)
        : 'Class Representative';

    String dateRangeStr = 'Full Semester / All Recorded Time';
    if (report.startDate != null && report.endDate != null) {
      dateRangeStr =
          '${AttendanceSessionModel.formatDate(report.startDate!)} to ${AttendanceSessionModel.formatDate(report.endDate!)}';
    } else if (report.startDate != null) {
      dateRangeStr =
          'From ${AttendanceSessionModel.formatDate(report.startDate!)}';
    } else if (report.endDate != null) {
      dateRangeStr =
          'Until ${AttendanceSessionModel.formatDate(report.endDate!)}';
    }

    final overallPctStr = AttendanceCalculationPolicy.formatPercentage(
      report.overallPercentage,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CR ATTENDANCE MANAGEMENT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        className,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (academicPeriod.isNotEmpty)
                        pw.Text(
                          academicPeriod,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'CR: $crName',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        'Period: $dateRangeStr',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Generated: ${DateTime.now().toIso8601String().split('.').first.replaceAll('T', ' ')}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CR Attendance Management Application · Offline Database Persistence',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          // 1. KPI Overview Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildKpiCard(
                  'Completed Sessions',
                  '${report.totalCompletedSessions}',
                  PdfColors.black,
                ),
                _buildKpiCard(
                  'Class Attendance Rate',
                  overallPctStr,
                  (report.overallPercentage ?? 0) >= 75.0
                      ? PdfColors.green800
                      : PdfColors.red800,
                ),
                _buildKpiCard(
                  'Total Marks',
                  '${report.totalRecords}',
                  PdfColors.black,
                ),
                _buildKpiCard(
                  'Present / Absent',
                  '${report.totalPresent}P · ${report.totalAbsent}A',
                  PdfColors.blue800,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 2. Student Register Section
          pw.Text(
            'STUDENT ATTENDANCE REGISTER',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 4),

          if (report.studentStats.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 20),
              child: pw.Center(
                child: pw.Text(
                  'No student records available for the selected period.',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(42), // Roll No
                1: const pw.FlexColumnWidth(3), // Student Name
                2: const pw.FixedColumnWidth(36), // Sessions
                3: const pw.FixedColumnWidth(28), // Present
                4: const pw.FixedColumnWidth(28), // Absent
                5: const pw.FixedColumnWidth(26), // Late
                6: const pw.FixedColumnWidth(26), // Leave
                7: const pw.FixedColumnWidth(48), // Attendance %
                8: const pw.FixedColumnWidth(44), // Status
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildCell(
                      'Roll No',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell('Student Name', isHeader: true),
                    _buildCell(
                      'Sessions',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Pres',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Abs',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Late',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Leave',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Att %',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                    _buildCell(
                      'Status',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                  ],
                ),
                // Data Rows
                ...report.studentStats.map((s) {
                  final pctStr = AttendanceCalculationPolicy.formatPercentage(
                    s.percentage,
                  );
                  final isBelow75 =
                      s.percentage != null && s.percentage! < 75.0;
                  final statusText = s.percentage == null
                      ? 'N/A'
                      : (isBelow75 ? 'Shortage' : 'Eligible');

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isBelow75 ? PdfColors.red50 : PdfColors.white,
                    ),
                    children: [
                      _buildCell(
                        s.student.rollNumber,
                        align: pw.TextAlign.center,
                        bold: true,
                      ),
                      _buildCell(
                        s.student.name + (s.isDeactivated ? ' [Inactive]' : ''),
                      ),
                      _buildCell(
                        '${s.totalSessions}',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        '${s.presentCount}',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        '${s.absentCount}',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell('${s.lateCount}', align: pw.TextAlign.center),
                      _buildCell('${s.leaveCount}', align: pw.TextAlign.center),
                      _buildCell(
                        pctStr,
                        align: pw.TextAlign.right,
                        bold: true,
                        color: isBelow75 ? PdfColors.red800 : PdfColors.black,
                      ),
                      _buildCell(
                        statusText,
                        align: pw.TextAlign.center,
                        color: isBelow75
                            ? PdfColors.red800
                            : PdfColors.green800,
                        bold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),

          pw.SizedBox(height: 18),

          // 3. Subject Summary Section
          pw.Text(
            'SUBJECT-WISE ATTENDANCE BREAKDOWN',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 4),

          if (report.subjectStats.isEmpty)
            pw.Text(
              'No subject records available.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(48), // Code
                1: const pw.FlexColumnWidth(3), // Subject Name
                2: const pw.FixedColumnWidth(40), // Sessions
                3: const pw.FixedColumnWidth(36), // Present
                4: const pw.FixedColumnWidth(36), // Absent
                5: const pw.FixedColumnWidth(32), // Late
                6: const pw.FixedColumnWidth(32), // Leave
                7: const pw.FixedColumnWidth(54), // Att %
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildCell(
                      'Code',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell('Subject Name', isHeader: true),
                    _buildCell(
                      'Sessions',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Present',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Absent',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Late',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Leave',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildCell(
                      'Subject %',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                // Data Rows
                ...report.subjectStats.map((sub) {
                  final subPctStr =
                      AttendanceCalculationPolicy.formatPercentage(
                        sub.percentage,
                      );
                  return pw.TableRow(
                    children: [
                      _buildCell(
                        sub.subject.code ?? '—',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        sub.subject.name +
                            (sub.isArchived ? ' [Archived]' : ''),
                      ),
                      _buildCell(
                        '${sub.totalSessions}',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        '${sub.presentCount}',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        '${sub.absentCount}',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        '${sub.lateCount}',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        '${sub.leaveCount}',
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        subPctStr,
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiCard(
    String label,
    String value,
    PdfColor valueColor,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: valueColor,
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader || bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.black : PdfColors.grey900),
        ),
        maxLines: 2,
      ),
    );
  }
}
