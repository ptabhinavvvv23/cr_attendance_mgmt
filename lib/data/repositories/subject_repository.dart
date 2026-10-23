import 'package:uuid/uuid.dart';

import '../../core/errors/database_exception.dart';
import '../local/dao/class_dao.dart';
import '../local/dao/subject_dao.dart';
import '../models/subject_model.dart';

/// Repository contract for academic Subject operations.
abstract class SubjectRepository {
  Future<SubjectModel> createSubject({
    required String classId,
    required String name,
    String? code,
  });

  Future<SubjectModel?> getSubjectById(String id);
  Future<List<SubjectModel>> getSubjectsByClass(
    String classId, {
    bool activeOnly = true,
  });
  Future<SubjectModel> updateSubject(SubjectModel subject);
  Future<void> deactivateSubject(String subjectId);
  Future<bool> hasHistoricalSessions(String subjectId);
}

/// Concrete SQLite implementation of [SubjectRepository].
class SubjectRepositoryImpl implements SubjectRepository {
  final SubjectDao _subjectDao;
  final ClassDao _classDao;
  final Uuid _uuid;

  SubjectRepositoryImpl({
    SubjectDao? subjectDao,
    ClassDao? classDao,
    Uuid? uuid,
  }) : _subjectDao = subjectDao ?? SubjectDao(),
       _classDao = classDao ?? ClassDao(),
       _uuid = uuid ?? const Uuid();

  @override
  Future<SubjectModel> createSubject({
    required String classId,
    required String name,
    String? code,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ValidationException('Subject name cannot be empty.');
    }

    // Verify parent class exists
    final parentClass = await _classDao.getById(classId);
    if (parentClass == null) {
      throw RecordNotFoundException('Class', classId);
    }

    // Check uniqueness within the class
    final existing = await _subjectDao.getByName(classId, cleanName);
    if (existing != null) {
      throw DuplicateEntityException('Subject', 'name', cleanName);
    }

    final now = DateTime.now();
    final subject = SubjectModel(
      id: _uuid.v4(),
      classId: classId,
      name: cleanName,
      code: code?.trim().toUpperCase(),
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _subjectDao.insert(subject);
      return subject;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to create subject: $e', e, st);
    }
  }

  @override
  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      return await _subjectDao.getById(id);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to retrieve subject $id: $e', e, st);
    }
  }

  @override
  Future<List<SubjectModel>> getSubjectsByClass(
    String classId, {
    bool activeOnly = true,
  }) async {
    try {
      return await _subjectDao.getByClassId(classId, activeOnly: activeOnly);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve subjects for class $classId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<SubjectModel> updateSubject(SubjectModel subject) async {
    final cleanName = subject.name.trim();
    if (cleanName.isEmpty) {
      throw ValidationException('Subject name cannot be empty.');
    }

    // Check for duplicate name if renamed
    final existingWithSameName = await _subjectDao.getByName(
      subject.classId,
      cleanName,
    );
    if (existingWithSameName != null && existingWithSameName.id != subject.id) {
      throw DuplicateEntityException('Subject', 'name', cleanName);
    }

    final updated = subject.copyWith(
      name: cleanName,
      code: subject.code?.trim().toUpperCase(),
      updatedAt: DateTime.now(),
    );

    try {
      final rowsAffected = await _subjectDao.update(updated);
      if (rowsAffected == 0) {
        throw RecordNotFoundException('Subject', subject.id);
      }
      return updated;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to update subject ${subject.id}: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<void> deactivateSubject(String subjectId) async {
    final existing = await getSubjectById(subjectId);
    if (existing == null) {
      throw RecordNotFoundException('Subject', subjectId);
    }
    // Deactivation preserves foreign key integrity with historical sessions
    final deactivated = existing.copyWith(
      isActive: false,
      updatedAt: DateTime.now(),
    );
    await updateSubject(deactivated);
  }

  @override
  Future<bool> hasHistoricalSessions(String subjectId) async {
    try {
      final count = await _subjectDao.countSessionsForSubject(subjectId);
      return count > 0;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to count sessions for subject $subjectId: $e',
        e,
        st,
      );
    }
  }
}
