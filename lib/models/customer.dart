class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.shoulder,
    required this.chest,
    required this.waist,
    required this.hips,
    required this.sleeveLength,
    required this.garmentLength,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final int id;
  final String name;
  final String phone;
  final String notes;
  final double? shoulder;
  final double? chest;
  final double? waist;
  final double? hips;
  final double? sleeveLength;
  final double? garmentLength;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get hasMeasurements =>
      shoulder != null ||
      chest != null ||
      waist != null ||
      hips != null ||
      sleeveLength != null ||
      garmentLength != null;

  Map<String, double> get measurements => {
        if (shoulder != null) 'الكتف': shoulder!,
        if (chest != null) 'الصدر': chest!,
        if (waist != null) 'الخصر': waist!,
        if (hips != null) 'الورك': hips!,
        if (sleeveLength != null) 'طول الكم': sleeveLength!,
        if (garmentLength != null) 'الطول': garmentLength!,
      };
}
