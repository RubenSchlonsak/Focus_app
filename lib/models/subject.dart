class Subject {
  final int age;
  final double weightKg;
  final int heightCm;
  final double shoeSize;
  final String gender; // 'm' | 'f' | 'd'
  final String notes;

  const Subject({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.shoeSize,
    required this.gender,
    this.notes = '',
  });

  String get genderLabel =>
      gender == 'm' ? 'männlich' : gender == 'f' ? 'weiblich' : 'divers';

  Map<String, dynamic> toJson() => {
        'age': age,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'shoe_size': shoeSize,
        'gender': gender,
        'notes': notes,
      };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        age: (j['age'] as num).toInt(),
        weightKg: (j['weight_kg'] as num).toDouble(),
        heightCm: (j['height_cm'] as num).toInt(),
        shoeSize: (j['shoe_size'] as num).toDouble(),
        gender: j['gender'] as String,
        notes: j['notes'] as String? ?? '',
      );
}
