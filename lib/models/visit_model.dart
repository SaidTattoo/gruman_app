class ActivoFijoLocal {
  final int id;
  final String tipoEquipo;
  final String marca;
  final String potenciaEquipo;
  final String refrigerante;
  final String onOffInverter;
  final String suministra;
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
      id: json['id'] as int,
      tipoEquipo: json['tipo_equipo'] as String,
      marca: json['marca'] as String,
      potenciaEquipo: json['potencia_equipo'] as String,
      refrigerante: json['refrigerante'] as String,
      onOffInverter: json['on_off_inverter'] as String,
      suministra: json['suministra'] as String,
      codigoActivo: json['codigo_activo'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo_equipo': tipoEquipo,
      'marca': marca,
      'potencia_equipo': potenciaEquipo,
      'refrigerante': refrigerante,
      'on_off_inverter': onOffInverter,
      'suministra': suministra,
      'codigo_activo': codigoActivo,
    };
  }
}

class Local {
  final int id;
  final String direccion;
  final String nombreLocal;
  final String numeroLocal;
  final List<ActivoFijoLocal> activoFijoLocales;

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
      activoFijoLocales: (json['activoFijoLocales'] as List?)
              ?.map((e) => ActivoFijoLocal.fromJson(e))
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

class ActivoFijo {
  final int id;
  final String tipoEquipo;
  final String marca;

  ActivoFijo({
    required this.id,
    required this.tipoEquipo,
    required this.marca,
  });

  factory ActivoFijo.fromJson(Map<String, dynamic> json) {
    return ActivoFijo(
      id: json['id'] as int,
      tipoEquipo: json['tipo_equipo'] as String,
      marca: json['marca'] as String,
    );
  }
}

class Visit {
  final int id;
  final String? status;
  final String? tipoMantenimiento;
  final String? tipoServicioId;
  final String? fechaVisita;
  final String? observacion;
  final Local local;
  final Map<String, dynamic> client;
  final DateTime? fechaHoraInicioServicio;
  final int? activo_fijo_id;
  final bool clima;

  Visit({
    required this.id,
    this.status,
    this.tipoMantenimiento,
    this.tipoServicioId,
    this.fechaVisita,
    this.observacion,
    required this.local,
    required this.client,
    this.fechaHoraInicioServicio,
    this.activo_fijo_id,
    this.clima = false,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as int,
      status: json['status'] as String?,
      tipoMantenimiento: json['tipo_mantenimiento'] as String?,
      tipoServicioId: json['tipoServicioId']?.toString(),
      fechaVisita: json['fechaVisita'] as String?,
      observacion: json['observacion'] as String?,
      local: Local.fromJson(json['local']),
      client: json['client'] as Map<String, dynamic>? ?? {},
      fechaHoraInicioServicio: json['fecha_hora_inicio_servicio'] != null
          ? DateTime.parse(json['fecha_hora_inicio_servicio'] as String)
          : null,
      activo_fijo_id: json['activo_fijo_id'] as int?,
      clima: (json['client'] as Map<String, dynamic>?)?['clima'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': fechaVisita,
      'estado': status,
      'tipo': tipoMantenimiento,
      'local': local.toJson(),
      'tecnico': client,
    };
  }

  // Método estático para obtener el nombre del tipo de servicio
  static String getTipoServicioNombre(String? id) {
    final Map<String, String> tiposServicio = {
      '1': 'Reactivo',
      '2': 'Prueba',
      '3': 'Preventivo',
      '4': 'Correctivo',
      '5': 'Clima',
      '6': 'Cortinas',
      '7': 'Inversión',
      '8': 'Siniestro',
    };
    return tiposServicio[id] ?? 'No especificado';
  }

  Visit copyWith({
    DateTime? fechaHoraInicioServicio,
  }) {
    return Visit(
      id: id,
      fechaVisita: fechaVisita,
      tipoMantenimiento: tipoMantenimiento,
      status: status,
      local: local,
      client: client,
      fechaHoraInicioServicio:
          fechaHoraInicioServicio ?? this.fechaHoraInicioServicio,
    );
  }
}
