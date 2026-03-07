import '../models/vital.dart';

/// baseline_service.dart
/// Domain-layer analytic computation.
/// Computes personal reference values from a ledger window.

class BaselineService {
  /// Computes a rolling average for a list of vitals.
  /// No caching. No persistence access. Pure computation.
  static double? computeRollingAverage(List<Vital> vitals) {
    if (vitals.isEmpty) return null;

    final sum = vitals.fold<double>(0, (prev, element) => prev + element.value);
    return sum / vitals.length;
  }

  /// Verifies if a value is within a stable threshold of the baseline.
  static bool isStable(double value, double baseline, double thresholdPercent) {
    final diff = (value - baseline).abs();
    final allowed = baseline * (thresholdPercent / 100);
    return diff <= allowed;
  }
}
