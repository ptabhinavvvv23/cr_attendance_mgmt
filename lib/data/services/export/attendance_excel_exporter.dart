import 'package:excel/excel.dart';

import '../../models/attendance_record_model.dart';
import '../../models/attendance_session_model.dart';
import '../../models/attendance_stats_models.dart';
import '../../models/owner_model.dart';

/// Service responsible for generating multi-sheet Microsoft Excel (.xlsx) workbooks
/// with formatted headers, student registers, and subject metrics.
class AttendanceExcelExporter {
  const AttendanceExcelExporter();

  /// Generates a complete .xlsx workbook bytes.
  List<int> generateWorkbook({
    required ClassAttendanceReport report,
    OwnerModel? owner,
    List<AttendanceSessionModel>? sessions,
    List<AttendanceRecordModel>? records,
  }) {
    final excel = Excel.createExcel();

    // 1. Overview Sheet
    const overviewSheetName = 'Overview';
    excel.rename('Sheet1', overviewSheetName);
    final overviewSheet = excel[overviewSheetName];

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

    overviewSheet.appendRow([
      TextCellValue('CR ATTENDANCE MANAGEMENT — ATTENDANCE REPORT'),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Class:'),
      TextCellValue(className),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Academic Period:'),
      TextCellValue(academicPeriod),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Class Representative:'),
      TextCellValue(crName),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Date Range:'),
      TextCellValue(dateRangeStr),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Generated On:'),
      TextCellValue(
        DateTime.now().toIso8601String().split('.').first.replaceAll('T', ' '),
      ),
    ]);
    overviewSheet.appendRow([]); // Blank row
    overviewSheet.appendRow([TextCellValue('KEY ATTENDANCE METRICS')]);
    overviewSheet.appendRow([
      TextCellValue('Completed Sessions:'),
      IntCellValue(report.totalCompletedSessions),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Overall Class Attendance:'),
      TextCellValue(overallPctStr),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Total Attendance Marks:'),
      IntCellValue(report.totalRecords),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Total Present:'),
      IntCellValue(report.totalPresent),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Total Absent:'),
      IntCellValue(report.totalAbsent),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Total Late:'),
      IntCellValue(report.totalLate),
    ]);
    overviewSheet.appendRow([
      TextCellValue('Total Leave:'),
      IntCellValue(report.totalLeave),
    ]);

    // 2. Student Register Sheet
    const studentSheetName = 'Student Register';
    final studentSheet = excel[studentSheetName];

    studentSheet.appendRow([
      TextCellValue('Roll Number'),
      TextCellValue('Student Name'),
      TextCellValue('Enrollment Status'),
      TextCellValue('Completed Sessions'),
      TextCellValue('Present'),
      TextCellValue('Absent'),
      TextCellValue('Late'),
      TextCellValue('Leave'),
      TextCellValue('Unmarked'),
      TextCellValue('Attendance %'),
      TextCellValue('Eligibility Status'),
    ]);

    for (final s in report.studentStats) {
      final pctStr = AttendanceCalculationPolicy.formatPercentage(s.percentage);
      final eligibility = s.percentage == null
          ? 'N/A'
          : (s.percentage! >= 75.0 ? 'Eligible (>=75%)' : 'Shortage (<75%)');

      studentSheet.appendRow([
        TextCellValue(s.student.rollNumber),
        TextCellValue(s.student.name),
        TextCellValue(s.isDeactivated ? 'Inactive' : 'Active'),
        IntCellValue(s.totalSessions),
        IntCellValue(s.presentCount),
        IntCellValue(s.absentCount),
        IntCellValue(s.lateCount),
        IntCellValue(s.leaveCount),
        IntCellValue(s.unmarkedCount),
        TextCellValue(pctStr),
        TextCellValue(eligibility),
      ]);
    }

    // 3. Subject Summary Sheet
    const subjectSheetName = 'Subject Summary';
    final subjectSheet = excel[subjectSheetName];

    subjectSheet.appendRow([
      TextCellValue('Subject Code'),
      TextCellValue('Subject Name'),
      TextCellValue('Status'),
      TextCellValue('Sessions Conducted'),
      TextCellValue('Present'),
      TextCellValue('Absent'),
      TextCellValue('Late'),
      TextCellValue('Leave'),
      TextCellValue('Unmarked'),
      TextCellValue('Subject Attendance %'),
    ]);

    for (final sub in report.subjectStats) {
      final subPctStr = AttendanceCalculationPolicy.formatPercentage(
        sub.percentage,
      );

      subjectSheet.appendRow([
        TextCellValue(sub.subject.code ?? 'N/A'),
        TextCellValue(sub.subject.name),
        TextCellValue(sub.isArchived ? 'Archived' : 'Active'),
        IntCellValue(sub.totalSessions),
        IntCellValue(sub.presentCount),
        IntCellValue(sub.absentCount),
        IntCellValue(sub.lateCount),
        IntCellValue(sub.leaveCount),
        IntCellValue(sub.unmarkedCount),
        TextCellValue(subPctStr),
      ]);
    }

    // 4. Session Log Sheet (if session records available)
    if (sessions != null &&
        sessions.isNotEmpty &&
        records != null &&
        records.isNotEmpty) {
      const logSheetName = 'Session Log';
      final logSheet = excel[logSheetName];

      logSheet.appendRow([
        TextCellValue('Session Date'),
        TextCellValue('Period'),
        TextCellValue('Subject ID'),
        TextCellValue('Student ID'),
        TextCellValue('Status'),
        TextCellValue('Remarks'),
      ]);

      for (final r in records) {
        final session = sessions.firstWhere(
          (s) => s.id == r.sessionId,
          orElse: () => sessions.first,
        );

        logSheet.appendRow([
          TextCellValue(session.sessionDate),
          TextCellValue(session.period),
          TextCellValue(session.subjectId),
          TextCellValue(r.studentId),
          TextCellValue(AttendanceRecordModel.statusToDbString(r.status)),
          TextCellValue(r.remarks ?? ''),
        ]);
      }
    }

    return excel.save() ?? [];
  }
}
