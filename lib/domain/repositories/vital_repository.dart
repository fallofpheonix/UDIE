import '../models/vital.dart';

/// vital_repository.dart
/// Abstract contract for the Vitals ledger.
/// Enforces replaceability and defines the allowed data boundary.

abstract class VitalRepository {
  /// Adds a new measurement to the ledger.
  Future<void> add(Vital vital);

  /// Fetches records within a specific window (Law: No unbounded scans).
  Future<List<Vital>> fetchRange(DateTime from, DateTime to);

  /// Performs a soft delete to maintain deterministic history.
  Future<void> softDelete(String id);
}
