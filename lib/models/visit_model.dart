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
  final String tipoMantenimiento;
  final DateTime fechaIngreso;
  final String? observaciones;
  final String status;
  final DateTime fechaVisita;
  final Local local;
  final Map<String, dynamic> client;
  final DateTime? fechaHoraInicioServicio;
  final ActivoFijo? activoFijo;

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
    this.activoFijo,
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
      activoFijo: json['activo_fijo'] != null
          ? ActivoFijo.fromJson(json['activo_fijo'])
          : null,
    );
  }
}
