// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solicitud_visita.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SolicitudVisitaAdapter extends TypeAdapter<SolicitudVisita> {
  @override
  final int typeId = 0;

  @override
  SolicitudVisita read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SolicitudVisita(
      id: fields[0] as int,
      tipoMantenimiento: fields[1] as String,
      tipoServicioId: fields[2] as int,
      tipoSolicitud: fields[3] as String?,
      sectorTrabajoId: fields[4] as int,
      especialidad: fields[5] as String?,
      fechaIngreso: fields[6] as DateTime,
      ticketGruman: fields[7] as String?,
      observaciones: fields[8] as String,
      status: fields[9] as String,
      valorPorLocal: fields[10] as double?,
      imagenes: fields[11] as String?,
      fechaVisita: fields[12] as DateTime,
      tecnicoAsignadoId: fields[13] as int,
      tecnicoAsignadoId2: fields[14] as int?,
      observacionRechazo: fields[15] as String?,
      fechaHoraInicioServicio: fields[16] as DateTime?,
      fechaHoraFinServicio: fields[17] as DateTime?,
      firmaCliente: fields[18] as String?,
      latitudMovil: fields[19] as String?,
      longitudMovil: fields[20] as String?,
      aprobadaPorId: fields[21] as int?,
      generadaPorId: fields[22] as int?,
      facturacionId: fields[23] as int?,
      estado: fields[24] as bool,
      activoFijoLocales: (fields[25] as List).cast<ActivoFijoLocal>(),
    );
  }

  @override
  void write(BinaryWriter writer, SolicitudVisita obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tipoMantenimiento)
      ..writeByte(2)
      ..write(obj.tipoServicioId)
      ..writeByte(3)
      ..write(obj.tipoSolicitud)
      ..writeByte(4)
      ..write(obj.sectorTrabajoId)
      ..writeByte(5)
      ..write(obj.especialidad)
      ..writeByte(6)
      ..write(obj.fechaIngreso)
      ..writeByte(7)
      ..write(obj.ticketGruman)
      ..writeByte(8)
      ..write(obj.observaciones)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.valorPorLocal)
      ..writeByte(11)
      ..write(obj.imagenes)
      ..writeByte(12)
      ..write(obj.fechaVisita)
      ..writeByte(13)
      ..write(obj.tecnicoAsignadoId)
      ..writeByte(14)
      ..write(obj.tecnicoAsignadoId2)
      ..writeByte(15)
      ..write(obj.observacionRechazo)
      ..writeByte(16)
      ..write(obj.fechaHoraInicioServicio)
      ..writeByte(17)
      ..write(obj.fechaHoraFinServicio)
      ..writeByte(18)
      ..write(obj.firmaCliente)
      ..writeByte(19)
      ..write(obj.latitudMovil)
      ..writeByte(20)
      ..write(obj.longitudMovil)
      ..writeByte(21)
      ..write(obj.aprobadaPorId)
      ..writeByte(22)
      ..write(obj.generadaPorId)
      ..writeByte(23)
      ..write(obj.facturacionId)
      ..writeByte(24)
      ..write(obj.estado)
      ..writeByte(25)
      ..write(obj.activoFijoLocales);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolicitudVisitaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ActivoFijoLocalAdapter extends TypeAdapter<ActivoFijoLocal> {
  @override
  final int typeId = 1;

  @override
  ActivoFijoLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActivoFijoLocal(
      id: fields[0] as int,
      tipoEquipo: fields[1] as String,
      marca: fields[2] as String,
      potenciaEquipo: fields[3] as String,
      refrigerante: fields[4] as String,
      onOffInverter: fields[5] as String,
      suministra: fields[6] as String,
      codigoActivo: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ActivoFijoLocal obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tipoEquipo)
      ..writeByte(2)
      ..write(obj.marca)
      ..writeByte(3)
      ..write(obj.potenciaEquipo)
      ..writeByte(4)
      ..write(obj.refrigerante)
      ..writeByte(5)
      ..write(obj.onOffInverter)
      ..writeByte(6)
      ..write(obj.suministra)
      ..writeByte(7)
      ..write(obj.codigoActivo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivoFijoLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
