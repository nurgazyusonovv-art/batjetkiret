class Enterprise {
  final int id;
  final String name;
  final String category;
  final String? address;
  final String? description;
  final String? phone;
  final double? lat;
  final double? lon;

  Enterprise({
    required this.id,
    required this.name,
    required this.category,
    this.address,
    this.description,
    this.phone,
    this.lat,
    this.lon,
  });

  factory Enterprise.fromJson(Map<String, dynamic> json) {
    return Enterprise(
      id: json['id'] as int,
      name: json['name'] as String,
      category: (json['category'] as String?) ?? '',
      address: json['address'] as String?,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

// ── Enterprise menu models ────────────────────────────────────────────────────

class EnterpriseMenuProduct {
  final int id;
  final String name;
  final String? description;
  final double price;

  EnterpriseMenuProduct({
    required this.id,
    required this.name,
    this.description,
    required this.price,
  });

  factory EnterpriseMenuProduct.fromJson(Map<String, dynamic> json) {
    return EnterpriseMenuProduct(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
    );
  }
}

class EnterpriseMenuCategory {
  final int id;
  final String name;
  final List<EnterpriseMenuProduct> products;

  EnterpriseMenuCategory({
    required this.id,
    required this.name,
    required this.products,
  });

  factory EnterpriseMenuCategory.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'] as List<dynamic>? ?? [];
    return EnterpriseMenuCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      products: rawProducts
          .map((p) => EnterpriseMenuProduct.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EnterpriseMenu {
  final Enterprise enterprise;
  final List<EnterpriseMenuCategory> categories;

  EnterpriseMenu({required this.enterprise, required this.categories});

  factory EnterpriseMenu.fromJson(Map<String, dynamic> json) {
    final rawCats = json['menu'] as List<dynamic>? ?? [];
    return EnterpriseMenu(
      enterprise: Enterprise.fromJson(json['enterprise'] as Map<String, dynamic>),
      categories: rawCats
          .map((c) => EnterpriseMenuCategory.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasProducts => categories.any((c) => c.products.isNotEmpty);
}
