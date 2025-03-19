class Especialidad {
  final int id;
  final String nombre;
  final bool deleted;

  Especialidad({
    required this.id,
    required this.nombre,
    required this.deleted,
  });

  factory Especialidad.fromJson(Map<String, dynamic> json) {
    return Especialidad(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      deleted: json['deleted'] as bool,
    );
  }
}

class Cliente {
  final int id;
  final String nombre;
  final String rut;
  final String logo;

  Cliente({
    required this.id,
    required this.nombre,
    required this.rut,
    required this.logo,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      rut: json['rut'] as String,
      logo: json['logo'] as String? ?? '',
    );
  }
}

class UserModel {
  final int id;
  final String email;
  final String name;
  final String rut;
  final List<Especialidad> especialidades;
  final String profile;
  final List<Cliente> clients;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.rut,
    required this.especialidades,
    required this.profile,
    required this.clients,
  });

  factory UserModel.fromDecodedToken(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rut: json['rut'] as String? ?? '',
      especialidades: (json['especialidades'] as List?)
              ?.map((e) => Especialidad.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      profile: json['profile'] as String? ?? '',
      clients: (json['clients'] as List?)
              ?.map((e) => Cliente.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
