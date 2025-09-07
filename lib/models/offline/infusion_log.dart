import 'package:hive/hive.dart';

part 'infusion_log.g.dart';

@HiveType(typeId: 1)
class InfusionLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String medication;

  @HiveField(2)
  int doseIU;

  @HiveField(3)
  String date;

  @HiveField(4)
  String time;

  @HiveField(5)
  String notes;

  @HiveField(6)
  String uid;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? syncedAt;

  @HiveField(9)
  bool needsSync;

  @HiveField(10)
  String lotNumber;

  InfusionLog({
    required this.id,
    required this.medication,
    required this.doseIU,
    required this.date,
    required this.time,
    required this.notes,
    required this.uid,
    required this.createdAt,
    this.syncedAt,
    this.needsSync = true,
    this.lotNumber = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'medication': medication,
      'doseIU': doseIU,
      'date': date,
      'time': time,
      'notes': notes,
      'uid': uid,
      'createdAt': createdAt.toIso8601String(),
      'lotNumber': lotNumber,
    };
  }
}
