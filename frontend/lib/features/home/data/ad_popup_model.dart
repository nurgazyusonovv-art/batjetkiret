class AdPopupItem {
  final int id;
  final String? title;
  final String? subtitle;
  final String? imageData;
  final String? linkUrl;
  final int? enterpriseId;
  final String? enterpriseName;
  final String? enterpriseCategory;

  const AdPopupItem({
    required this.id,
    this.title,
    this.subtitle,
    this.imageData,
    this.linkUrl,
    this.enterpriseId,
    this.enterpriseName,
    this.enterpriseCategory,
  });

  bool get hasEnterprise => enterpriseId != null;

  factory AdPopupItem.fromJson(Map<String, dynamic> json) => AdPopupItem(
        id: json['id'] as int,
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        imageData: json['image_data'] as String?,
        linkUrl: json['link_url'] as String?,
        enterpriseId: json['enterprise_id'] as int?,
        enterpriseName: json['enterprise_name'] as String?,
        enterpriseCategory: json['enterprise_category'] as String?,
      );
}
