class InspeccionList {
  final int id;
  final String name;
  final bool disabled;
  final List<ChecklistItem> items;

  InspeccionList({
    required this.id,
    required this.name,
    required this.disabled,
    required this.items,
  });

  factory InspeccionList.fromJson(Map<String, dynamic> json) {
    return InspeccionList(
      id: json['id'] as int,
      name: json['name'] as String,
      disabled: json['disabled'] as bool,
      items: (json['items'] as List)
          .map((e) => ChecklistItem.fromJson(e))
          .toList(),
    );
  }
}

class ChecklistItem {
  final int id;
  final String name;
  final bool disabled;
  final List<SubItem> subItems;

  ChecklistItem({
    required this.id,
    required this.name,
    required this.disabled,
    required this.subItems,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as int,
      name: json['name'] as String,
      disabled: json['disabled'] as bool,
      subItems:
          (json['subItems'] as List).map((e) => SubItem.fromJson(e)).toList(),
    );
  }
}

class Item {
  final int id;
  final String name;
  final bool disabled;
  final List<SubItem> subItems;

  Item({
    required this.id,
    required this.name,
    this.disabled = false,
    required this.subItems,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      disabled: json['disabled'] ?? false,
      subItems: (json['subItems'] as List)
          .map((item) => SubItem.fromJson(item))
          .toList(),
    );
  }
}

class SubItem {
  final int id;
  final int itemId;
  final String name;
  final bool fotoObligatoria;
  final bool disabled;

  SubItem({
    required this.id,
    required this.itemId,
    required this.name,
    required this.fotoObligatoria,
    this.disabled = false,
  });

  factory SubItem.fromJson(Map<String, dynamic> json) {
    final itemId = json['item_id'] ?? json['itemId'] ?? json['id'];

    return SubItem(
      id: json['id'],
      itemId: itemId,
      name: json['name'],
      fotoObligatoria: json['foto_obligatoria'] ?? false,
      disabled: json['disabled'] ?? false,
    );
  }
}
