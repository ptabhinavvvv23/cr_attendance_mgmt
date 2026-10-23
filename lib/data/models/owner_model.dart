/// Persistent representation of the Class Representative (CR) or local device owner.
class OwnerModel {
  final String id;
  final String registrationNumber;
  final String? displayName;
  final String? email;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? metadata;

  const OwnerModel({
    required this.id,
    required this.registrationNumber,
    this.displayName,
    this.email,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'registration_number': registrationNumber.trim(),
      'display_name': displayName?.trim(),
      'email': email?.trim().toLowerCase(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory OwnerModel.fromMap(Map<String, dynamic> map) {
    return OwnerModel(
      id: map['id'] as String,
      registrationNumber: map['registration_number'] as String,
      displayName: map['display_name'] as String?,
      email: map['email'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      metadata: map['metadata'] as String?,
    );
  }

  OwnerModel copyWith({
    String? id,
    String? registrationNumber,
    String? displayName,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? metadata,
  }) {
    return OwnerModel(
      id: id ?? this.id,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OwnerModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
