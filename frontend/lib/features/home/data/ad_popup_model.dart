class AdPopupItem {
  final int id;
  final String? title;
  final String? subtitle;
  final String? imageData;
  final String? linkUrl;

  const AdPopupItem({
    required this.id,
    this.title,
    this.subtitle,
    this.imageData,
    this.linkUrl,
  });

  factory AdPopupItem.fromJson(Map<String, dynamic> json) => AdPopupItem(
        id: json['id'] as int,
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        imageData: json['image_data'] as String?,
        linkUrl: json['link_url'] as String?,
      );
}
