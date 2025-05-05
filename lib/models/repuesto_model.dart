class Repuesto {
  final int id;
  final String familia;
  final String articulo;
  final String marca;
  final String codigoBarra;
  final double precio_compra;
  final double precio_venta;
  final double valor_uf;
  final bool clima;

  Repuesto({
    required this.id,
    required this.familia,
    required this.articulo,
    required this.marca,
    required this.codigoBarra,
    required this.precio_compra,
    required this.precio_venta,
    required this.valor_uf,
    required this.clima,
  });

  factory Repuesto.fromJson(Map<String, dynamic> json) {
    return Repuesto(
      id: int.parse(json['id'].toString()),
      familia: json['familia'] ?? '',
      articulo: json['articulo'] ?? '',
      marca: json['marca'] ?? '',
      codigoBarra: json['codigoBarra'] ?? '',
      precio_compra: double.tryParse(json['precio_compra'].toString()) ?? 0.0,
      precio_venta: double.tryParse(json['precio_venta'].toString()) ?? 0.0,
      valor_uf: double.tryParse(json['valor_uf'].toString()) ?? 0.0,
      clima: json['clima'] == 1 || json['clima'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familia': familia,
      'articulo': articulo,
      'marca': marca,
      'codigoBarra': codigoBarra,
      'precio_compra': precio_compra,
      'precio_venta': precio_venta,
      'valor_uf': valor_uf,
      'clima': clima,
    };
  }
}
