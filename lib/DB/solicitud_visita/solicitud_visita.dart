import 'package:hive/hive.dart';

part 'solicitud_visita.g.dart';

@HiveType(typeId: 0)
class SolicitudVisita extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String tipoMantenimiento;

  @HiveField(2)
  final int tipoServicioId;

  @HiveField(3)
  final String? tipoSolicitud;

  @HiveField(4)
  final int sectorTrabajoId;

  @HiveField(5)
  final String? especialidad;

  @HiveField(6)
  final DateTime fechaIngreso;

  @HiveField(7)
  final String? ticketGruman;

  @HiveField(8)
  final String observaciones;

  @HiveField(9)
  final String status;

  @HiveField(10)
  final double? valorPorLocal;

  @HiveField(11)
  final String? imagenes;

  @HiveField(12)
  final DateTime fechaVisita;

  @HiveField(13)
  final int tecnicoAsignadoId;

  @HiveField(14)
  final int? tecnicoAsignadoId2;

  @HiveField(15)
  final String? observacionRechazo;

  @HiveField(16)
  final DateTime? fechaHoraInicioServicio;

  @HiveField(17)
  final DateTime? fechaHoraFinServicio;

  @HiveField(18)
  final String? firmaCliente;

  @HiveField(19)
  final String? latitudMovil;

  @HiveField(20)
  final String? longitudMovil;

  @HiveField(21)
  final int? aprobadaPorId;

  @HiveField(22)
  final int? generadaPorId;

  @HiveField(23)
  final int? facturacionId;

  @HiveField(24)
  final bool estado;

  @HiveField(25)
  final List<ActivoFijoLocal> activoFijoLocales;

  SolicitudVisita({
    required this.id,
    required this.tipoMantenimiento,
    required this.tipoServicioId,
    this.tipoSolicitud,
    required this.sectorTrabajoId,
    this.especialidad,
    required this.fechaIngreso,
    this.ticketGruman,
    required this.observaciones,
    required this.status,
    this.valorPorLocal,
    this.imagenes,
    required this.fechaVisita,
    required this.tecnicoAsignadoId,
    this.tecnicoAsignadoId2,
    this.observacionRechazo,
    this.fechaHoraInicioServicio,
    this.fechaHoraFinServicio,
    this.firmaCliente,
    this.latitudMovil,
    this.longitudMovil,
    this.aprobadaPorId,
    this.generadaPorId,
    this.facturacionId,
    required this.estado,
    required this.activoFijoLocales,
  });

  factory SolicitudVisita.fromJson(Map<String, dynamic> json) {
    return SolicitudVisita(
      id: json['id'],
      tipoMantenimiento: json['tipo_mantenimiento'],
      tipoServicioId: json['tipoServicioId'],
      tipoSolicitud: json['tipoSolicitud'],
      sectorTrabajoId: json['sectorTrabajoId'],
      especialidad: json['especialidad'],
      fechaIngreso: DateTime.parse(json['fechaIngreso']),
      ticketGruman: json['ticketGruman'],
      observaciones: json['observaciones'],
      status: json['status'],
      valorPorLocal: json['valorPorLocal']?.toDouble(),
      imagenes: json['imagenes'],
      fechaVisita: DateTime.parse(json['fechaVisita']),
      tecnicoAsignadoId: json['tecnico_asignado_id'],
      tecnicoAsignadoId2: json['tecnico_asignado_id_2'],
      observacionRechazo: json['observacion_rechazo'],
      fechaHoraInicioServicio: json['fecha_hora_inicio_servicio'] != null
          ? DateTime.parse(json['fecha_hora_inicio_servicio'])
          : null,
      fechaHoraFinServicio: json['fecha_hora_fin_servicio'] != null
          ? DateTime.parse(json['fecha_hora_fin_servicio'])
          : null,
      firmaCliente: json['firma_cliente'],
      latitudMovil: json['latitud_movil'],
      longitudMovil: json['longitud_movil'],
      aprobadaPorId: json['aprobada_por_id'],
      generadaPorId: json['generada_por_id'],
      facturacionId: json['facturacion_id'],
      estado: json['estado'],
      activoFijoLocales: (json['local']['activoFijoLocales'] as List)
          .map((x) => ActivoFijoLocal.fromJson(x))
          .toList(),
    );
  }
}

@HiveType(typeId: 1)
class ActivoFijoLocal extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String tipoEquipo;

  @HiveField(2)
  final String marca;

  @HiveField(3)
  final String potenciaEquipo;

  @HiveField(4)
  final String refrigerante;

  @HiveField(5)
  final String onOffInverter;

  @HiveField(6)
  final String suministra;

  @HiveField(7)
  final String codigoActivo;

  ActivoFijoLocal({
    required this.id,
    required this.tipoEquipo,
    required this.marca,
    required this.potenciaEquipo,
    required this.refrigerante,
    required this.onOffInverter,
    required this.suministra,
    required this.codigoActivo,
  });

  factory ActivoFijoLocal.fromJson(Map<String, dynamic> json) {
    return ActivoFijoLocal(
      id: json['id'],
      tipoEquipo: json['tipo_equipo'],
      marca: json['marca'],
      potenciaEquipo: json['potencia_equipo'],
      refrigerante: json['refrigerante'],
      onOffInverter: json['on_off_inverter'],
      suministra: json['suministra'],
      codigoActivo: json['codigo_activo'],
    );
  }
}
