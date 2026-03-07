import '../../domain/models/vital.dart';

/// vital_record.dart
/// Infrastructure-layer DTO for persistence.
/// This is the only place allowed to contain serialization logic.

class VitalRecord {
  final String id;
  final String type;
  final double value;
  final String unit;
  final int timestamp;
  final int createdAt;
  final int updatedAt;
  final int version;
  final bool isDeleted;

  const VitalRecord({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.isDeleted = false,
  });

  /// Map from Domain Vital to Infrastructure VitalRecord.
  factory VitalRecord.fromDomain(Vital vital) {
    return VitalRecord(
      id: vital.id,
      type: vital.type.name,
      value: vital.value,
      unit: vital.unit,
      timestamp: vital.timestamp.millisecondsSinceEpoch,
      createdAt: vital.createdAt.millisecondsSinceEpoch,
      updatedAt: vital.updatedAt.millisecondsSinceEpoch,
      version: vital.version,
      isDeleted: vital.isDeleted,
    );
  }

  /// Map from Infrastructure VitalRecord to Domain Vital.
  Vital toDomain() {
    return Vital(
      id: id,
      type: VitalType.values.byName(type),
      value: value,
      unit: unit,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      version: version,
      isDeleted: isDeleted,
    );
  }

  /// JSON serialization for storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'unit': unit,
        'timestamp': timestamp,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'version': version,
        'isDeleted': isDeleted,
      };

  factory VitalRecord.fromJson(Map<String, dynamic> json) => VitalRecord(
        id: json['id'],
        type: json['type'],
        value: json['value'],
        unit: json['unit'],
        timestamp: json['timestamp'],
        createdAt: json['createdAt'],
        updatedAt: json['updatedAt'],
        version: json['version'],
        isDeleted: json['isDeleted'] ?? false,
      );
}
