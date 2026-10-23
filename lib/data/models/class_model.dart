/// Persistent representation of a Class profile managed by a CR.
class ClassModel {
  final String id;
  final String ownerId;
  final String name;
  final String academicYear;
  final String section;
  final String? semester;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClassModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.academicYear,
    required this.section,
    this.semester,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name.trim(),
      'academic_year': academicYear.trim(),
      'section': section.trim(),
      'semester': semester?.trim(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      academicYear: map['academic_year'] as String,
      section: map['section'] as String,
      semester: map['semester'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ClassModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? academicYear,
    String? section,
    String? semester,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      academicYear: academicYear ?? this.academicYear,
      section: section ?? this.section,
      semester: semester ?? this.semester,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
