class Repuesto {
  final int id;
  final String familia;
  final String articulo;
  final String marca;
  final String codigoBarra;
  final int precio;
  final int precioNetoCompra;
  final int sobreprecio;
  final int precioIva;
  final int precioBruto;

  Repuesto({
    required this.id,
    required this.familia,
    required this.articulo,
    required this.marca,
    required this.codigoBarra,
    required this.precio,
    required this.precioNetoCompra,
    required this.sobreprecio,
    required this.precioIva,
    required this.precioBruto,
  });

  factory Repuesto.fromJson(Map<String, dynamic> json) {
    return Repuesto(
      id: json['id'] as int,
      familia: json['familia'] as String,
      articulo: json['articulo'] as String,
      marca: json['marca'] as String,
      codigoBarra: json['codigoBarra'] as String,
      precio: json['precio'] as int,
      precioNetoCompra: json['precioNetoCompra'] as int,
      sobreprecio: json['sobreprecio'] as int,
      precioIva: json['precioIva'] as int,
      precioBruto: json['precioBruto'] as int,
    );
  }
}

class RepuestoAsignado {
  final Repuesto repuesto;
  int cantidad;
  String? comentario;

  RepuestoAsignado({
    required this.repuesto,
    required this.cantidad,
    this.comentario,
  });
}
