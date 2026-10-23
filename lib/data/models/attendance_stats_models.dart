import '../../core/theme/app_colors.dart';
import 'class_model.dart';
import 'student_model.dart';
import 'subject_model.dart';

/// Defines how different attendance statuses are treated when calculating attendance percentage.
enum LeavePolicy {
  /// Excused: Leave is excluded from the opportunities denominator so students
  /// are not penalized for authorized absence/medical leaves.
  excused,

  /// Uncredited: Leave counts as an opportunity with 0.0 credit (treated like an absence).
  uncredited,

  /// Credited: Leave is credited with 1.0 credit and counts as an opportunity (e.g. On-Duty / official duty leave).
  credited,
}

/// Centralized, explicit, and consistent policy for calculating attendance percentages and credits.
/// Ensures all reports, summaries, and dashboard statistics use identical math.
class AttendanceCalculationPolicy {
  /// Credit awarded for [AttendanceStatus.present] (default: 1.0).
  final double presentCredit;

  /// Credit awarded for [AttendanceStatus.late] (default: 1.0, student attended class).
  final double lateCredit;

  /// Policy for handling [AttendanceStatus.leave] (default: [LeavePolicy.excused]).
  final LeavePolicy leavePolicy;

  const AttendanceCalculationPolicy({
    this.presentCredit = 1.0,
    this.lateCredit = 1.0,
    this.leavePolicy = LeavePolicy.excused,
  });

  /// Standard default policy for CR Attendance Management.
  static const AttendanceCalculationPolicy standard =
      AttendanceCalculationPolicy();

  /// Calculates the attendance percentage:
  /// (eligible attendance credit / eligible attendance opportunities) * 100
  ///
  /// Returns `null` if eligible attendance opportunities is 0 (safely handles empty denominators
  /// without producing `NaN`, `Infinity`, or an erroneous `0.0%`).
  ///
  /// Note: [AttendanceStatus.unmarked] records do NOT award credit and are NOT silently counted as absences.
  double? calculatePercentage({
    required int presentCount,
    required int absentCount,
    required int lateCount,
    required int leaveCount,
    int unmarkedCount = 0,
  }) {
    double credit = (presentCount * presentCredit) + (lateCount * lateCredit);
    if (leavePolicy == LeavePolicy.credited) {
      credit += leaveCount * 1.0;
    }

    int opportunities = presentCount + absentCount + lateCount;
    if (leavePolicy == LeavePolicy.uncredited ||
        leavePolicy == LeavePolicy.credited) {
      opportunities += leaveCount;
    }

    if (opportunities <= 0) {
      return null;
    }

    final percentage = (credit / opportunities) * 100.0;
    return percentage.clamp(0.0, 100.0);
  }

  /// Formats percentage safely for display: returns "—" if null, otherwise "XX.X%".
  static String formatPercentage(double? percentage, {int fractionDigits = 1}) {
    if (percentage == null) return '—';
    if (percentage == percentage.roundToDouble()) {
      return '${percentage.toInt()}%';
    }
    return '${percentage.toStringAsFixed(fractionDigits)}%';
  }
}

/// Aggregated attendance statistics for a single student across a designated timeframe.
class StudentAttendanceStats {
  final StudentModel student;
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final int unmarkedCount;
  final double? percentage;
  final bool isDeactivated;
  final Map<String, SubjectAttendanceStats> subjectBreakdown;

  const StudentAttendanceStats({
    required this.student,
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
    required this.unmarkedCount,
    required this.percentage,
    this.isDeactivated = false,
    this.subjectBreakdown = const {},
  });

  /// The number of sessions in which this student was credited with attendance.
  double get totalCreditedSessions => (presentCount * 1.0) + (lateCount * 1.0);
}

/// Aggregated attendance statistics for an academic subject across a designated timeframe.
class SubjectAttendanceStats {
  final SubjectModel subject;
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final int unmarkedCount;
  final double? percentage;
  final bool isArchived;

  const SubjectAttendanceStats({
    required this.subject,
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
    required this.unmarkedCount,
    required this.percentage,
    this.isArchived = false,
  });

  int get totalRecords =>
      presentCount + absentCount + lateCount + leaveCount + unmarkedCount;
}

/// Complete attendance report container for a class across a specific timeframe or subject scope.
class ClassAttendanceReport {
  final String classId;
  final ClassModel? classModel;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? subjectId;
  final int totalCompletedSessions;
  final int totalRecords;
  final int totalPresent;
  final int totalAbsent;
  final int totalLate;
  final int totalLeave;
  final int totalUnmarked;
  final double? overallPercentage;
  final List<StudentAttendanceStats> studentStats;
  final List<SubjectAttendanceStats> subjectStats;
  final AttendanceCalculationPolicy policy;

  const ClassAttendanceReport({
    required this.classId,
    this.classModel,
    this.startDate,
    this.endDate,
    this.subjectId,
    required this.totalCompletedSessions,
    required this.totalRecords,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalLate,
    required this.totalLeave,
    required this.totalUnmarked,
    required this.overallPercentage,
    required this.studentStats,
    required this.subjectStats,
    this.policy = AttendanceCalculationPolicy.standard,
  });

  bool get isEmpty => totalCompletedSessions == 0;
}
