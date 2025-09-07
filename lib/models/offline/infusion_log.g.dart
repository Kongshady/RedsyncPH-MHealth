// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'infusion_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InfusionLogAdapter extends TypeAdapter<InfusionLog> {
  @override
  final int typeId = 1;

  @override
  InfusionLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InfusionLog(
      id: fields[0] as String,
      medication: fields[1] as String,
      doseIU: fields[2] as int,
      date: fields[3] as String,
      time: fields[4] as String,
      notes: fields[5] as String,
      uid: fields[6] as String,
      createdAt: fields[7] as DateTime,
      syncedAt: fields[8] as DateTime?,
      needsSync: fields[9] as bool,
      lotNumber: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, InfusionLog obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medication)
      ..writeByte(2)
      ..write(obj.doseIU)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.time)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.uid)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.syncedAt)
      ..writeByte(9)
      ..write(obj.needsSync)
      ..writeByte(10)
      ..write(obj.lotNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfusionLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
