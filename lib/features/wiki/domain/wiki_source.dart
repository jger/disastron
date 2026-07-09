import 'package:flutter/foundation.dart';

@immutable
class WikiSource {
  const WikiSource({
    required this.url,
    required this.title,
    required this.category,
    required this.locale,
  });

  factory WikiSource.fromMap(Map<dynamic, dynamic> map) => WikiSource(
    url: map['url']?.toString() ?? '',
    title: map['title']?.toString() ?? '',
    category: map['category']?.toString() ?? '',
    locale: map['locale']?.toString() ?? 'en',
  );
  final String url;
  final String title;
  final String category;
  final String locale;

  Map<String, String> toMap() => {
    'url': url,
    'title': title,
    'category': category,
    'locale': locale,
  };

  WikiSource copyWith({
    String? url,
    String? title,
    String? category,
    String? locale,
  }) {
    return WikiSource(
      url: url ?? this.url,
      title: title ?? this.title,
      category: category ?? this.category,
      locale: locale ?? this.locale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WikiSource &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          title == other.title &&
          category == other.category &&
          locale == other.locale;

  @override
  int get hashCode =>
      url.hashCode ^ title.hashCode ^ category.hashCode ^ locale.hashCode;
}
