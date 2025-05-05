import 'dart:convert';

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'deleted': deleted,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'rut': rut,
      'logo': logo,
    };
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
  final bool isOffline;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.rut,
    required this.especialidades,
    required this.profile,
    required this.clients,
    this.isOffline = false,
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
      isOffline: false,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      rut: json['rut'] as String,
      profile: json['profile'] as String,
      isOffline: json['isOffline'] as bool? ?? false,
      especialidades: (json['especialidades'] as List?)
              ?.map((e) => Especialidad.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      clients: (json['clients'] as List?)
              ?.map((e) => Cliente.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'rut': rut,
      'profile': profile,
      'isOffline': isOffline ? 1 : 0,
      'especialidades':
          jsonEncode(especialidades.map((e) => e.toJson()).toList()),
      'clients': jsonEncode(clients.map((e) => e.toJson()).toList()),
    };
  }
}
