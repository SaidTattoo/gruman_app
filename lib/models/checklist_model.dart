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

class SubItem {
  final int id;
  final String name;
  final bool disabled;

  SubItem({
    required this.id,
    required this.name,
    required this.disabled,
  });

  factory SubItem.fromJson(Map<String, dynamic> json) {
    return SubItem(
      id: json['id'] as int,
      name: json['name'] as String,
      disabled: json['disabled'] as bool,
    );
  }
}
