class BannerItem {
  final int id;
  final String? title;
  final String? subtitle;
  final String? imageData; // base64 data URL
  final String? linkUrl;
  final bool isActive;
  final int sortOrder;
  final int viewCount;
  final int showDays; // 0 = unlimited

  const BannerItem({
    required this.id,
    this.title,
    this.subtitle,
    this.imageData,
    this.linkUrl,
    required this.isActive,
    required this.sortOrder,
    this.viewCount = 0,
    this.showDays = 0,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: json['id'] as int,
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        imageData: json['image_data'] as String?,
        linkUrl: json['link_url'] as String?,
        isActive: (json['is_active'] as bool?) ?? true,
        sortOrder: (json['sort_order'] as int?) ?? 0,
        viewCount: (json['view_count'] as int?) ?? 0,
        showDays: (json['show_days'] as int?) ?? 0,
      );
}
