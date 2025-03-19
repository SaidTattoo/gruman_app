class DocumentoVehiculo {
  final int id;
  final String nombre;
  final DateTime fecha;
  final DateTime? fechaVencimiento;
  final String path;
  final bool activo;

  DocumentoVehiculo({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.fechaVencimiento,
    required this.path,
    required this.activo,
  });

  factory DocumentoVehiculo.fromJson(Map<String, dynamic> json) {
    return DocumentoVehiculo(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.parse(json['fechaVencimiento'] as String)
          : null,
      path: json['path'] as String,
      activo: json['activo'] as bool,
    );
  }
}

class VehicleModel {
  final int id;
  final String movil;
  final String patente;
  final String marca;
  final String modelo;
  final int anio;
  final bool activo;
  final int odometroInicio;
  final DateTime fechaUtilizado;
  final List<DocumentoVehiculo> documentos;

  VehicleModel({
    required this.id,
    required this.movil,
    required this.patente,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.activo,
    required this.odometroInicio,
    required this.fechaUtilizado,
    required this.documentos,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int,
      movil: json['movil'] as String,
      patente: json['patente'] as String,
      marca: json['marca'] as String,
      modelo: json['modelo'] as String,
      anio: json['anio'] as int,
      activo: json['activo'] as bool,
      odometroInicio: json['odometro_inicio'] as int,
      fechaUtilizado: DateTime.parse(json['fecha_utilizado'] as String),
      documentos: (json['documentos'] as List)
          .map((e) => DocumentoVehiculo.fromJson(e))
          .toList(),
    );
  }
}
