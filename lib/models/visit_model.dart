class Local {
  final int id;
  final String direccion;
  final String nombreLocal;
  final String numeroLocal;

  Local({
    required this.id,
    required this.direccion,
    required this.nombreLocal,
    required this.numeroLocal,
  });

  factory Local.fromJson(Map<String, dynamic> json) {
    return Local(
      id: json['id'] as int,
      direccion: json['direccion'] as String,
      nombreLocal: json['nombre_local'] as String,
      numeroLocal: json['numeroLocal'] as String,
    );
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
    );
  }
}
