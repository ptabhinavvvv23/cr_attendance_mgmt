/// Persistent representation of a Student enrolled in a Class.
class StudentModel {
  final String id;
  final String classId;
  final String rollNumber;
  final String normalizedRollNumber;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentModel({
    required this.id,
    required this.classId,
    required this.rollNumber,
    String? normalizedRollNumber,
    required this.name,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) : normalizedRollNumber =
           normalizedRollNumber ?? normalizeRollNumber(rollNumber);

  /// Consistent normalization logic for student roll numbers:
  /// trims leading/trailing whitespace and converts to uppercase.
  static String normalizeRollNumber(String raw) {
    return raw.trim().toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'roll_number': rollNumber.trim(),
      'normalized_roll_number': normalizedRollNumber,
      'name': name.trim(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    final rawRoll = map['roll_number'] as String;
    return StudentModel(
      id: map['id'] as String,
      classId: map['class_id'] as String,
      rollNumber: rawRoll,
      normalizedRollNumber:
          (map['normalized_roll_number'] as String?) ??
          normalizeRollNumber(rawRoll),
      name: map['name'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  StudentModel copyWith({
    String? id,
    String? classId,
    String? rollNumber,
    String? normalizedRollNumber,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      rollNumber: rollNumber ?? this.rollNumber,
      normalizedRollNumber: normalizedRollNumber ?? this.normalizedRollNumber,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
