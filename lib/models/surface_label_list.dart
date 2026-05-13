class SurfaceLabelList {
  final String name;
  final List<String> surfaces;

  const SurfaceLabelList({required this.name, required this.surfaces});

  SurfaceLabelList copyWith({String? name, List<String>? surfaces}) =>
      SurfaceLabelList(
        name: name ?? this.name,
        surfaces: surfaces ?? List.from(this.surfaces),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'surfaces': List<String>.from(surfaces),
      };

  factory SurfaceLabelList.fromJson(Map<String, dynamic> json) =>
      SurfaceLabelList(
        name: json['name'] as String,
        surfaces: List<String>.from(json['surfaces'] as List),
      );
}
