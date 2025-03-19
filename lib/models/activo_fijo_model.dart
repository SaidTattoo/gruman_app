class ActivoFijo {
  final int id;
  final String tipoEquipo;
  final String marca;
  final String potenciaEquipo;
  final String refrigerante;
  final String onOffInverter;
  final String suministra;
  final String codigoActivo;

  ActivoFijo({
    required this.id,
    required this.tipoEquipo,
    required this.marca,
    required this.potenciaEquipo,
    required this.refrigerante,
    required this.onOffInverter,
    required this.suministra,
    required this.codigoActivo,
  });

  factory ActivoFijo.fromJson(Map<String, dynamic> json) {
    return ActivoFijo(
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
