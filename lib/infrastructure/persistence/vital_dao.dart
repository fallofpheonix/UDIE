import 'vital_record.dart';

/// vital_dao.dart
/// Simple Data Access Object for simulation of local storage.
/// In a real app, this would wrap Hive, Isar, or SQLite.

class VitalDao {
  // Mock in-memory storage for demonstration.
  final Map<String, Map<String, dynamic>> _storage = {};

  Future<void> insert(VitalRecord record) async {
    _storage[record.id] = record.toJson();
  }

  Future<List<VitalRecord>> queryRange(int from, int to) async {
    return _storage.values
        .map((e) => VitalRecord.fromJson(e))
        .where((e) => e.timestamp >= from && e.timestamp <= to)
        .where((e) => !e.isDeleted)
        .toList();
  }

  Future<void> update(VitalRecord record) async {
    _storage[record.id] = record.toJson();
  }

  Future<VitalRecord?> findById(String id) async {
    final data = _storage[id];
    if (data == null) return null;
    return VitalRecord.fromJson(data);
  }
}
