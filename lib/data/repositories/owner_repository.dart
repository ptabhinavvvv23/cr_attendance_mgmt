import 'package:uuid/uuid.dart';

import '../../core/errors/database_exception.dart';
import '../local/dao/owner_dao.dart';
import '../models/owner_model.dart';

/// Repository contract for CR identity and local owner operations.
abstract class OwnerRepository {
  Future<OwnerModel> createOwner({
    required String registrationNumber,
    String? displayName,
    String? email,
    String? metadata,
  });

  Future<OwnerModel?> getOwnerById(String id);
  Future<OwnerModel?> getCurrentOwner();
  Future<OwnerModel> updateOwner(OwnerModel owner);
}

/// Concrete SQLite implementation of [OwnerRepository].
class OwnerRepositoryImpl implements OwnerRepository {
  final OwnerDao _ownerDao;
  final Uuid _uuid;

  OwnerRepositoryImpl({OwnerDao? ownerDao, Uuid? uuid})
    : _ownerDao = ownerDao ?? OwnerDao(),
      _uuid = uuid ?? const Uuid();

  @override
  Future<OwnerModel> createOwner({
    required String registrationNumber,
    String? displayName,
    String? email,
    String? metadata,
  }) async {
    final cleanReg = registrationNumber.trim();
    if (cleanReg.isEmpty) {
      throw ValidationException('Owner registration number cannot be blank.');
    }

    final now = DateTime.now();
    final owner = OwnerModel(
      id: _uuid.v4(),
      registrationNumber: cleanReg,
      displayName: displayName?.trim(),
      email: email?.trim().toLowerCase(),
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );

    try {
      await _ownerDao.insert(owner);
      return owner;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to create CR owner record: $e', e, st);
    }
  }

  @override
  Future<OwnerModel?> getOwnerById(String id) async {
    try {
      return await _ownerDao.getById(id);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve owner with ID $id: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<OwnerModel?> getCurrentOwner() async {
    try {
      return await _ownerDao.getCurrentOwner();
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to retrieve current owner: $e', e, st);
    }
  }

  @override
  Future<OwnerModel> updateOwner(OwnerModel owner) async {
    final cleanReg = owner.registrationNumber.trim();
    if (cleanReg.isEmpty) {
      throw ValidationException('Owner registration number cannot be blank.');
    }

    final updated = owner.copyWith(
      registrationNumber: cleanReg,
      displayName: owner.displayName?.trim(),
      email: owner.email?.trim().toLowerCase(),
      updatedAt: DateTime.now(),
    );

    try {
      final rowsAffected = await _ownerDao.update(updated);
      if (rowsAffected == 0) {
        throw RecordNotFoundException('Owner', owner.id);
      }
      return updated;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to update owner ${owner.id}: $e', e, st);
    }
  }
}
