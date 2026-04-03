class BannerItem {
  final int id;
  final String? title;
  final String? subtitle;
  final String? imageData; // base64 data URL
  final String? linkUrl;
  final bool isActive;
  final int sortOrder;

  const BannerItem({
    required this.id,
    this.title,
    this.subtitle,
    this.imageData,
    this.linkUrl,
    required this.isActive,
    required this.sortOrder,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: json['id'] as int,
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        imageData: json['image_data'] as String?,
        linkUrl: json['link_url'] as String?,
        isActive: (json['is_active'] as bool?) ?? true,
        sortOrder: (json['sort_order'] as int?) ?? 0,
      );
}
