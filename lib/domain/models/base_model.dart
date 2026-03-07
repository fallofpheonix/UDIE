/// base_model.dart
/// Domain-layer base for all immutable ledger records.
/// Contains zero framework dependencies and no serialization logic.

class BaseModel {
  final String id;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final bool isDeleted;

  const BaseModel({
    required this.id,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.isDeleted = false,
  });
}
