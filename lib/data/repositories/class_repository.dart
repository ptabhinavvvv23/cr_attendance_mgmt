import 'package:uuid/uuid.dart';

import '../../core/errors/database_exception.dart';
import '../local/dao/class_dao.dart';
import '../local/dao/owner_dao.dart';
import '../models/class_model.dart';

/// Repository contract for Class profile operations.
abstract class ClassRepository {
  Future<ClassModel> createClass({
    required String ownerId,
    required String name,
    required String academicYear,
    required String section,
    String? semester,
  });

  Future<ClassModel?> getClassById(String id);
  Future<List<ClassModel>> getClassesForOwner(String ownerId);
  Future<ClassModel?> getActiveClassForOwner(String ownerId);
  Future<ClassModel> updateClass(ClassModel classModel);
  Future<void> archiveClass(String classId);
  Future<void> activateClass(String classId);
}

/// Concrete SQLite implementation of [ClassRepository].
class ClassRepositoryImpl implements ClassRepository {
  final ClassDao _classDao;
  final OwnerDao _ownerDao;
  final Uuid _uuid;

  ClassRepositoryImpl({ClassDao? classDao, OwnerDao? ownerDao, Uuid? uuid})
    : _classDao = classDao ?? ClassDao(),
      _ownerDao = ownerDao ?? OwnerDao(),
      _uuid = uuid ?? const Uuid();

  @override
  Future<ClassModel> createClass({
    required String ownerId,
    required String name,
    required String academicYear,
    required String section,
    String? semester,
  }) async {
    final cleanName = name.trim();
    final cleanYear = academicYear.trim();
    final cleanSection = section.trim();

    if (cleanName.isEmpty) {
      throw ValidationException('Class name cannot be empty.');
    }
    if (cleanYear.isEmpty) {
      throw ValidationException('Academic year cannot be empty.');
    }
    if (cleanSection.isEmpty) {
      throw ValidationException('Section cannot be empty.');
    }

    // Verify owner existence
    final owner = await _ownerDao.getById(ownerId);
    if (owner == null) {
      throw RecordNotFoundException('Owner', ownerId);
    }

    final now = DateTime.now();
    final newClass = ClassModel(
      id: _uuid.v4(),
      ownerId: ownerId,
      name: cleanName,
      academicYear: cleanYear,
      section: cleanSection,
      semester: semester?.trim(),
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _classDao.insert(newClass);
      return newClass;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to create class record: $e', e, st);
    }
  }

  @override
  Future<ClassModel?> getClassById(String id) async {
    try {
      return await _classDao.getById(id);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to retrieve class $id: $e', e, st);
    }
  }

  @override
  Future<List<ClassModel>> getClassesForOwner(String ownerId) async {
    try {
      return await _classDao.getByOwnerId(ownerId);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve classes for owner $ownerId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<ClassModel?> getActiveClassForOwner(String ownerId) async {
    try {
      return await _classDao.getActiveClassForOwner(ownerId);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve active class for owner $ownerId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<ClassModel> updateClass(ClassModel classModel) async {
    final cleanName = classModel.name.trim();
    final cleanYear = classModel.academicYear.trim();
    final cleanSection = classModel.section.trim();

    if (cleanName.isEmpty || cleanYear.isEmpty || cleanSection.isEmpty) {
      throw ValidationException(
        'Class name, academic year, and section cannot be empty.',
      );
    }

    final updated = classModel.copyWith(
      name: cleanName,
      academicYear: cleanYear,
      section: cleanSection,
      semester: classModel.semester?.trim(),
      updatedAt: DateTime.now(),
    );

    try {
      final rowsAffected = await _classDao.update(updated);
      if (rowsAffected == 0) {
        throw RecordNotFoundException('Class', classModel.id);
      }
      return updated;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to update class ${classModel.id}: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<void> archiveClass(String classId) async {
    final existing = await getClassById(classId);
    if (existing == null) {
      throw RecordNotFoundException('Class', classId);
    }
    final archived = existing.copyWith(
      isActive: false,
      updatedAt: DateTime.now(),
    );
    await updateClass(archived);
  }

  @override
  Future<void> activateClass(String classId) async {
    final target = await getClassById(classId);
    if (target == null) {
      throw RecordNotFoundException('Class', classId);
    }
    // Deactivate any currently active class for this owner to ensure consistent active class
    final currentActive = await getActiveClassForOwner(target.ownerId);
    if (currentActive != null && currentActive.id != classId) {
      await updateClass(
        currentActive.copyWith(isActive: false, updatedAt: DateTime.now()),
      );
    }
    final activated = target.copyWith(
      isActive: true,
      updatedAt: DateTime.now(),
    );
    await updateClass(activated);
  }
}
