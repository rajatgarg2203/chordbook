class SongModel {
  final String id;
  final String title;
  final String? album;
  final int? year;
  final String content;
  final String? key;
  final int? capo;
  final int? tempo;
  final int? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> artistNames;

  SongModel({
    required this.id,
    required this.title,
    this.album,
    this.year,
    required this.content,
    this.key,
    this.capo,
    this.tempo,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.artistNames = const [],
  });

  SongModel copyWith({
    String? id,
    String? title,
    String? album,
    int? year,
    String? content,
    String? key,
    int? capo,
    int? tempo,
    int? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? artistNames,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      album: album ?? this.album,
      year: year ?? this.year,
      content: content ?? this.content,
      key: key ?? this.key,
      capo: capo ?? this.capo,
      tempo: tempo ?? this.tempo,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      artistNames: artistNames ?? this.artistNames,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'album': album,
      'year': year,
      'content': content,
      'key': key,
      'capo': capo,
      'tempo': tempo,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'artistNames': artistNames,
    };
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'] as String,
      title: json['title'] as String,
      album: json['album'] as String?,
      year: json['year'] as int?,
      content: json['content'] as String,
      key: json['key'] as String?,
      capo: json['capo'] as int?,
      tempo: json['tempo'] as int?,
      category: json['category'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      artistNames: (json['artistNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
