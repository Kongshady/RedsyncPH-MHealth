// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication_reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicationReminderAdapter extends TypeAdapter<MedicationReminder> {
  @override
  final int typeId = 4;

  @override
  MedicationReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicationReminder(
      id: fields[0] as String,
      uid: fields[1] as String,
      medicationName: fields[2] as String,
      dosage: fields[3] as String,
      administrationType: fields[4] as String,
      frequency: fields[5] as String,
      reminderTimeHour: fields[6] as int,
      reminderTimeMinute: fields[7] as int,
      notificationEnabled: fields[8] as bool,
      startDate: fields[9] as DateTime,
      endDate: fields[10] as DateTime,
      notes: fields[11] as String,
      isActive: fields[12] as bool,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
      takenDates: (fields[15] as List?)?.cast<String>(),
      notificationId: fields[16] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MedicationReminder obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.uid)
      ..writeByte(2)
      ..write(obj.medicationName)
      ..writeByte(3)
      ..write(obj.dosage)
      ..writeByte(4)
      ..write(obj.administrationType)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.reminderTimeHour)
      ..writeByte(7)
      ..write(obj.reminderTimeMinute)
      ..writeByte(8)
      ..write(obj.notificationEnabled)
      ..writeByte(9)
      ..write(obj.startDate)
      ..writeByte(10)
      ..write(obj.endDate)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.isActive)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.takenDates)
      ..writeByte(16)
      ..write(obj.notificationId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
