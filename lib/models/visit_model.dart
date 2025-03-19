import 'activo_fijo_model.dart';

class Local {
  final int id;
  final String direccion;
  final String nombreLocal;
  final String numeroLocal;
  final List<ActivoFijo> activoFijoLocales;

  Local({
    required this.id,
    required this.direccion,
    required this.nombreLocal,
    required this.numeroLocal,
    required this.activoFijoLocales,
  });

  factory Local.fromJson(Map<String, dynamic> json) {
    return Local(
      id: json['id'] as int,
      direccion: json['direccion'] as String,
      nombreLocal: json['nombre_local'] as String,
      numeroLocal: json['numeroLocal'] as String,
      activoFijoLocales: (json['activoFijoLocales'] as List<dynamic>?)
              ?.map((e) => ActivoFijo.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'direccion': direccion,
      'nombre_local': nombreLocal,
      'numeroLocal': numeroLocal,
      'activoFijoLocales': activoFijoLocales.map((e) => e.toJson()).toList(),
    };
  }
}

class Visit {
  final int id;
  final String tipoMantenimiento;
  final DateTime fechaIngreso;
  final String? observaciones;
  final String status;
  final DateTime fechaVisita;
  final Local local;
  final Map<String, dynamic> client;
  final DateTime? fechaHoraInicioServicio;
  final List<Map<String, dynamic>> activoFijoRepuestos;

  Visit({
    required this.id,
    required this.tipoMantenimiento,
    required this.fechaIngreso,
    this.observaciones,
    required this.status,
    required this.fechaVisita,
    required this.local,
    required this.client,
    this.fechaHoraInicioServicio,
    required this.activoFijoRepuestos,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as int,
      tipoMantenimiento: json['tipo_mantenimiento'] as String? ?? '',
      fechaIngreso: DateTime.parse(json['fechaIngreso'] as String),
      observaciones: json['observaciones'] as String?,
      status: json['status'] as String? ?? 'pending',
      fechaVisita: DateTime.parse(json['fechaVisita'] as String),
      local: Local.fromJson(json['local'] as Map<String, dynamic>),
      client: json['client'] as Map<String, dynamic>,
      fechaHoraInicioServicio: json['fecha_hora_inicio_servicio'] != null
          ? DateTime.parse(json['fecha_hora_inicio_servicio'] as String)
          : null,
      activoFijoRepuestos: (json['activoFijoRepuestos'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo_mantenimiento': tipoMantenimiento,
      'fechaIngreso': fechaIngreso.toIso8601String(),
      'observaciones': observaciones,
      'status': status,
      'fechaVisita': fechaVisita.toIso8601String(),
      'local': local.toJson(),
      'client': client,
      'fecha_hora_inicio_servicio': fechaHoraInicioServicio?.toIso8601String(),
      'activoFijoRepuestos': activoFijoRepuestos,
    };
  }
}
