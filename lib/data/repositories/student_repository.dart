import 'package:uuid/uuid.dart';

import '../../core/errors/database_exception.dart';
import '../local/dao/class_dao.dart';
import '../local/dao/student_dao.dart';
import '../models/student_model.dart';

/// Repository contract for Student management operations.
abstract class StudentRepository {
  Future<StudentModel> createStudent({
    required String classId,
    required String rollNumber,
    required String name,
  });

  Future<StudentModel?> getStudentById(String id);
  Future<List<StudentModel>> getActiveStudentsByClass(String classId);
  Future<List<StudentModel>> getAllStudentsByClass(String classId);
  Future<List<StudentModel>> searchStudents(
    String classId,
    String query, {
    bool activeOnly = false,
  });
  Future<StudentModel> updateStudent(StudentModel student);
  Future<void> deactivateStudent(String studentId);
  Future<bool> hasHistoricalAttendance(String studentId);
}

/// Concrete SQLite implementation of [StudentRepository].
class StudentRepositoryImpl implements StudentRepository {
  final StudentDao _studentDao;
  final ClassDao _classDao;
  final Uuid _uuid;

  StudentRepositoryImpl({
    StudentDao? studentDao,
    ClassDao? classDao,
    Uuid? uuid,
  }) : _studentDao = studentDao ?? StudentDao(),
       _classDao = classDao ?? ClassDao(),
       _uuid = uuid ?? const Uuid();

  @override
  Future<StudentModel> createStudent({
    required String classId,
    required String rollNumber,
    required String name,
  }) async {
    final cleanName = name.trim();
    final cleanRoll = rollNumber.trim();

    if (cleanName.isEmpty) {
      throw ValidationException('Student name cannot be empty.');
    }
    if (cleanRoll.isEmpty) {
      throw ValidationException('Roll number cannot be empty.');
    }

    // Verify class exists
    final parentClass = await _classDao.getById(classId);
    if (parentClass == null) {
      throw RecordNotFoundException('Class', classId);
    }

    final normalizedRoll = StudentModel.normalizeRollNumber(cleanRoll);

    // Enforce roll number uniqueness within class scope
    final existing = await _studentDao.getByRollNumber(classId, normalizedRoll);
    if (existing != null) {
      throw DuplicateRollNumberException(
        rollNumber: cleanRoll,
        classId: classId,
      );
    }

    final now = DateTime.now();
    final student = StudentModel(
      id: _uuid.v4(),
      classId: classId,
      rollNumber: cleanRoll,
      normalizedRollNumber: normalizedRoll,
      name: cleanName,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _studentDao.insert(student);
      return student;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to create student: $e', e, st);
    }
  }

  @override
  Future<StudentModel?> getStudentById(String id) async {
    try {
      return await _studentDao.getById(id);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to retrieve student $id: $e', e, st);
    }
  }

  @override
  Future<List<StudentModel>> getActiveStudentsByClass(String classId) async {
    try {
      return await _studentDao.getByClassId(classId, activeOnly: true);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve active students for class $classId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<List<StudentModel>> getAllStudentsByClass(String classId) async {
    try {
      return await _studentDao.getByClassId(classId, activeOnly: false);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve all students for class $classId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<List<StudentModel>> searchStudents(
    String classId,
    String query, {
    bool activeOnly = false,
  }) async {
    try {
      return await _studentDao.search(classId, query, activeOnly: activeOnly);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to search students in class $classId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<StudentModel> updateStudent(StudentModel student) async {
    final cleanName = student.name.trim();
    final cleanRoll = student.rollNumber.trim();

    if (cleanName.isEmpty) {
      throw ValidationException('Student name cannot be empty.');
    }
    if (cleanRoll.isEmpty) {
      throw ValidationException('Roll number cannot be empty.');
    }

    final normalizedRoll = StudentModel.normalizeRollNumber(cleanRoll);

    // If roll number is updated, check for collision with another student in the same class
    final existingWithRoll = await _studentDao.getByRollNumber(
      student.classId,
      normalizedRoll,
    );
    if (existingWithRoll != null && existingWithRoll.id != student.id) {
      throw DuplicateRollNumberException(
        rollNumber: cleanRoll,
        classId: student.classId,
      );
    }

    final updated = student.copyWith(
      name: cleanName,
      rollNumber: cleanRoll,
      normalizedRollNumber: normalizedRoll,
      updatedAt: DateTime.now(),
    );

    try {
      final rowsAffected = await _studentDao.update(updated);
      if (rowsAffected == 0) {
        throw RecordNotFoundException('Student', student.id);
      }
      return updated;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to update student ${student.id}: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<void> deactivateStudent(String studentId) async {
    final existing = await getStudentById(studentId);
    if (existing == null) {
      throw RecordNotFoundException('Student', studentId);
    }

    // Soft deactivation preserves all historical attendance sessions and records
    try {
      final rowsAffected = await _studentDao.deactivate(studentId);
      if (rowsAffected == 0) {
        throw RecordNotFoundException('Student', studentId);
      }
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to deactivate student $studentId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<bool> hasHistoricalAttendance(String studentId) async {
    try {
      final count = await _studentDao.countAttendanceRecords(studentId);
      return count > 0;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to check attendance history for student $studentId: $e',
        e,
        st,
      );
    }
  }
}
