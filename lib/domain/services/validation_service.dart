import '../models/vital.dart';

/// validation_service.dart
/// Domain-layer validation for health records.
/// Pure functions only. Zero side effects.

class ValidationService {
  static void validateVital(Vital vital) {
    _validateValue(vital.type, vital.value);
    _validateTimestamp(vital.timestamp);
  }

  static void _validateValue(VitalType type, double value) {
    if (value < 0) {
      throw DomainValidationException('Value cannot be negative: $value');
    }

    switch (type) {
      case VitalType.heartRate:
        if (value < 25 || value > 240) {
          throw DomainValidationException('Impossible heart rate: $value');
        }
        break;
      case VitalType.weight:
        if (value > 600) {
          throw DomainValidationException('Weight exceeds human maximum: $value');
        }
        break;
    }
  }

  static void _validateTimestamp(DateTime timestamp) {
    if (timestamp.isAfter(DateTime.now())) {
      throw DomainValidationException('Timestamp cannot be in the future.');
    }
  }
}

class DomainValidationException implements Exception {
  final String message;
  DomainValidationException(this.message);
  @override
  String toString() => 'Validation Failure: $message';
}
