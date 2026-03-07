import '../../domain/models/vital.dart';
import '../../domain/repositories/vital_repository.dart';
import '../persistence/vital_dao.dart';
import '../persistence/vital_record.dart';

/// local_vital_repository.dart
/// Implementation of the VitalRepository contract.
/// This acts as the adapter between the Domain and Infrastructure layers.

class LocalVitalRepository implements VitalRepository {
  final VitalDao _dao;

  LocalVitalRepository(this._dao);

  @override
  Future<void> add(Vital vital) async {
    final record = VitalRecord.fromDomain(vital);
    await _dao.insert(record);
  }

  @override
  Future<List<Vital>> fetchRange(DateTime from, DateTime to) async {
    final records = await _dao.queryRange(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    return records.map((e) => e.toDomain()).toList();
  }

  @override
  Future<void> softDelete(String id) async {
    final record = await _dao.findById(id);
    if (record == null) return;

    final updated = VitalRecord(
      id: record.id,
      type: record.type,
      value: record.value,
      unit: record.unit,
      timestamp: record.timestamp,
      createdAt: record.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      version: record.version + 1,
      isDeleted: true,
    );

    await _dao.update(updated);
  }
}
