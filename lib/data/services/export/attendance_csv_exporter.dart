import 'dart:convert';

import '../../models/attendance_session_model.dart';
import '../../models/attendance_stats_models.dart';
import '../../models/owner_model.dart';

/// Service responsible for generating standardized RFC 4180 compliant CSV exports
/// of attendance reports, student registers, and subject summaries.
class AttendanceCsvExporter {
  const AttendanceCsvExporter();

  /// Escapes a CSV field according to RFC 4180:
  /// Encloses in double quotes if it contains commas, double quotes, or newlines,
  /// and doubles any inner quotation marks.
  static String escape(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') ||
        str.contains('"') ||
        str.contains('\n') ||
        str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Generates a comprehensive attendance register CSV containing class summary,
  /// student attendance records, and subject breakdown.
  /// Prepends a UTF-8 Byte Order Mark (BOM) for seamless Microsoft Excel compatibility.
  List<int> generateReportCsv({
    required ClassAttendanceReport report,
    OwnerModel? owner,
  }) {
    final buffer = StringBuffer();

    // 1. Class & Report Metadata Section
    final className = report.classModel != null
        ? '${report.classModel!.name} — Section ${report.classModel!.section}'
        : 'Class ID: ${report.classId}';
    final academicYear = report.classModel?.academicYear ?? '';
    final semester = report.classModel?.semester ?? '';
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

    buffer.writeln(escape('CR ATTENDANCE MANAGEMENT — ATTENDANCE REPORT'));
    buffer.writeln('${escape('Class')},${escape(className)}');
    buffer.writeln(
      '${escape('Academic Period')},${escape('$academicYear${semester.isNotEmpty ? ' • $semester' : ''}')}',
    );
    buffer.writeln('${escape('Class Representative')},${escape(crName)}');
    buffer.writeln('${escape('Report Date Range')},${escape(dateRangeStr)}');
    buffer.writeln(
      '${escape('Generated On')},${escape(DateTime.now().toIso8601String().split('.').first.replaceAll('T', ' '))}',
    );
    buffer.writeln(
      '${escape('Total Completed Sessions')},${escape(report.totalCompletedSessions)}',
    );
    buffer.writeln(
      '${escape('Overall Attendance %')},${escape(overallPctStr)}',
    );
    buffer.writeln(
      '${escape('Total Attendance Marks')},${escape(report.totalRecords)}',
    );
    buffer.writeln(
      '${escape('Summary Breakdown')},${escape('${report.totalPresent} Present, ${report.totalAbsent} Absent, ${report.totalLate} Late, ${report.totalLeave} Leave')}',
    );
    buffer.writeln(); // Empty separator row

    // 2. Student Attendance Register Table
    buffer.writeln(escape('--- STUDENT ATTENDANCE REGISTER ---'));
    final studentHeaders = [
      'Roll Number',
      'Student Name',
      'Status',
      'Total Sessions',
      'Present',
      'Absent',
      'Late',
      'Leave',
      'Unmarked',
      'Attendance %',
      'Eligibility (>=75%)',
    ];
    buffer.writeln(studentHeaders.map(escape).join(','));

    for (final s in report.studentStats) {
      final pctStr = AttendanceCalculationPolicy.formatPercentage(s.percentage);
      final eligibility = s.percentage == null
          ? 'N/A'
          : (s.percentage! >= 75.0 ? 'Eligible' : 'Shortage');
      final studentStatus = s.isDeactivated ? 'Inactive' : 'Active';

      final row = [
        s.student.rollNumber,
        s.student.name,
        studentStatus,
        s.totalSessions,
        s.presentCount,
        s.absentCount,
        s.lateCount,
        s.leaveCount,
        s.unmarkedCount,
        pctStr,
        eligibility,
      ];
      buffer.writeln(row.map(escape).join(','));
    }

    buffer.writeln(); // Empty separator row

    // 3. Subject-wise Summary Table
    buffer.writeln(escape('--- SUBJECT-WISE ATTENDANCE SUMMARY ---'));
    final subjectHeaders = [
      'Subject Code',
      'Subject Name',
      'Status',
      'Completed Sessions',
      'Present',
      'Absent',
      'Late',
      'Leave',
      'Unmarked',
      'Subject Attendance %',
    ];
    buffer.writeln(subjectHeaders.map(escape).join(','));

    for (final sub in report.subjectStats) {
      final subPctStr = AttendanceCalculationPolicy.formatPercentage(
        sub.percentage,
      );
      final subStatus = sub.isArchived ? 'Archived' : 'Active';

      final row = [
        sub.subject.code ?? 'N/A',
        sub.subject.name,
        subStatus,
        sub.totalSessions,
        sub.presentCount,
        sub.absentCount,
        sub.lateCount,
        sub.leaveCount,
        sub.unmarkedCount,
        subPctStr,
      ];
      buffer.writeln(row.map(escape).join(','));
    }

    // Prepend UTF-8 Byte Order Mark (BOM) [0xEF, 0xBB, 0xBF]
    final utf8Bytes = utf8.encode(buffer.toString());
    return <int>[0xEF, 0xBB, 0xBF, ...utf8Bytes];
  }
}
