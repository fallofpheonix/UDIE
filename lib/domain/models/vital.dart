import 'base_model.dart';

/// vital.dart
/// Domain model for scalar time-based health measurements.

enum VitalType {
  weight,
  heartRate,
}

class Vital extends BaseModel {
  final VitalType type;
  final double value;
  final String unit;

  const Vital({
    required super.id,
    required super.timestamp,
    required super.createdAt,
    required super.updatedAt,
    required this.type,
    required this.value,
    required this.unit,
    super.version,
    super.isDeleted,
  });

  /// Every model behaves like a record, not an object graph.
  /// No UI formatting, no validation logic, no persistence details.
}
