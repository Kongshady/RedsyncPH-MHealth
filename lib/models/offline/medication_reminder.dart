import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'medication_reminder.g.dart';

@HiveType(typeId: 4)
class MedicationReminder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String uid;

  @HiveField(2)
  String medicationName;

  @HiveField(3)
  String dosage;

  @HiveField(4)
  String administrationType;

  @HiveField(5)
  String frequency;

  @HiveField(6)
  int reminderTimeHour;

  @HiveField(7)
  int reminderTimeMinute;

  @HiveField(8)
  bool notificationEnabled;

  @HiveField(9)
  DateTime startDate;

  @HiveField(10)
  DateTime endDate;

  @HiveField(11)
  String notes;

  @HiveField(12)
  bool isActive;

  @HiveField(13)
  DateTime createdAt;

  @HiveField(14)
  DateTime updatedAt;

  @HiveField(15)
  List<String>
      takenDates; // Store dates when medication was taken (YYYY-MM-DD format)

  @HiveField(16)
  int notificationId; // For local notifications

  MedicationReminder({
    required this.id,
    required this.uid,
    required this.medicationName,
    required this.dosage,
    required this.administrationType,
    required this.frequency,
    required this.reminderTimeHour,
    required this.reminderTimeMinute,
    required this.notificationEnabled,
    required this.startDate,
    required this.endDate,
    required this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    List<String>? takenDates,
    required this.notificationId,
  }) : takenDates = takenDates ?? [];

  // Helper getters
  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderTimeHour, minute: reminderTimeMinute);

  bool get isActiveToday {
    final today = DateTime.now();
    return isActive &&
        today.isAfter(startDate.subtract(const Duration(days: 1))) &&
        today.isBefore(endDate.add(const Duration(days: 1)));
  }

  bool get isTakenToday {
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return takenDates.contains(todayString);
  }

  bool shouldTakeToday() {
    if (!isActiveToday || isTakenToday) return false;

    final today = DateTime.now();
    final daysDifference = today.difference(startDate).inDays;

    switch (frequency) {
      case 'Daily':
        return true;
      case 'Once':
        return today.day == startDate.day &&
            today.month == startDate.month &&
            today.year == startDate.year;
      case 'Every 3 Days':
        return daysDifference % 3 == 0;
      default:
        return true;
    }
  }

  DateTime get todayReminderDateTime {
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
      reminderTimeHour,
      reminderTimeMinute,
    );
  }

  bool get isPending {
    return todayReminderDateTime.isAfter(DateTime.now());
  }

  bool get isOverdue {
    final now = DateTime.now();
    final reminderTime = todayReminderDateTime;
    return reminderTime.isBefore(now) &&
        reminderTime.isAfter(now.subtract(const Duration(hours: 2)));
  }

  void markAsTaken() {
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (!takenDates.contains(todayString)) {
      takenDates.add(todayString);
      save(); // Save to Hive
    }
  }

  void markAsNotTaken() {
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    takenDates.remove(todayString);
    save(); // Save to Hive
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'medicationName': medicationName,
      'dosage': dosage,
      'administrationType': administrationType,
      'frequency': frequency,
      'reminderTimeHour': reminderTimeHour,
      'reminderTimeMinute': reminderTimeMinute,
      'notificationEnabled': notificationEnabled,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'notes': notes,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'takenDates': takenDates,
      'notificationId': notificationId,
    };
  }

  static MedicationReminder fromMap(Map<String, dynamic> map) {
    return MedicationReminder(
      id: map['id'],
      uid: map['uid'],
      medicationName: map['medicationName'],
      dosage: map['dosage'],
      administrationType: map['administrationType'],
      frequency: map['frequency'],
      reminderTimeHour: map['reminderTimeHour'],
      reminderTimeMinute: map['reminderTimeMinute'],
      notificationEnabled: map['notificationEnabled'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      notes: map['notes'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      takenDates: List<String>.from(map['takenDates'] ?? []),
      notificationId: map['notificationId'],
    );
  }

  @override
  String toString() {
    return 'MedicationReminder(id: $id, medicationName: $medicationName, frequency: $frequency, isActive: $isActive)';
  }
}
