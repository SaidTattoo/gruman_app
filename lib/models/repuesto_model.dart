class Repuesto {
  final int id;
  final String familia;
  final String articulo;
  final String marca;
  final String codigoBarra;
  final double precioCompra;
  final double precioVenta;
  final bool valorUf;
  final bool clima;

  Repuesto({
    required this.id,
    required this.familia,
    required this.articulo,
    required this.marca,
    required this.codigoBarra,
    required this.precioCompra,
    required this.precioVenta,
    this.valorUf = false,
    this.clima = false,
  });

  factory Repuesto.fromJson(Map<String, dynamic> json) {
    return Repuesto(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      familia: json['familia']?.toString() ?? '',
      articulo: json['articulo']?.toString() ?? '',
      marca: json['marca']?.toString() ?? '',
      codigoBarra: json['codigoBarra']?.toString() ?? '',
      precioCompra:
          double.tryParse(json['precio_compra']?.toString() ?? '0') ?? 0.0,
      precioVenta:
          double.tryParse(json['precio_venta']?.toString() ?? '0') ?? 0.0,
      valorUf: json['valor_uf'] as bool? ?? false,
      clima: json['clima'] as bool? ?? false,
    );
  }
}
