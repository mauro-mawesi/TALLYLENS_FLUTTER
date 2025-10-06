// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_receipt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineReceiptAdapter extends TypeAdapter<OfflineReceipt> {
  @override
  final int typeId = 0;

  @override
  OfflineReceipt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineReceipt(
      localId: fields[0] as String,
      serverId: fields[1] as String?,
      imageLocalPath: fields[2] as String,
      imageUrl: fields[3] as String?,
      merchantName: fields[4] as String?,
      category: fields[5] as String?,
      amount: fields[6] as double?,
      currency: fields[7] as String?,
      purchaseDate: fields[8] as DateTime?,
      notes: fields[9] as String?,
      syncStatus: fields[10] as int,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      errorMessage: fields[13] as String?,
      retryCount: fields[14] as int,
      lastSyncAttempt: fields[15] as DateTime?,
      processedByMLKit: fields[16] as bool,
      source: fields[17] as String?,
      parsedData: (fields[18] as Map?)?.cast<String, dynamic>(),
      items: (fields[19] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineReceipt obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.serverId)
      ..writeByte(2)
      ..write(obj.imageLocalPath)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.merchantName)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.amount)
      ..writeByte(7)
      ..write(obj.currency)
      ..writeByte(8)
      ..write(obj.purchaseDate)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.syncStatus)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.errorMessage)
      ..writeByte(14)
      ..write(obj.retryCount)
      ..writeByte(15)
      ..write(obj.lastSyncAttempt)
      ..writeByte(16)
      ..write(obj.processedByMLKit)
      ..writeByte(17)
      ..write(obj.source)
      ..writeByte(18)
      ..write(obj.parsedData)
      ..writeByte(19)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineReceiptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
