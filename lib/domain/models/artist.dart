class Artist {
  final String id;
  final String name;

  Artist({
    required this.id,
    required this.name,
  });

  Artist copyWith({
    String? id,
    String? name,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
