import 'package:flutter_test/flutter_test.dart';
import 'package:mikhyat_pro/models/customer.dart';

void main() {
  test('العميل بدون مقاسات لا يعتبر لديه مقاسات محفوظة', () {
    final customer = Customer(
      id: 1,
      name: 'سارة',
      phone: '777000000',
      notes: '',
      shoulder: null,
      chest: null,
      waist: null,
      hips: null,
      sleeveLength: null,
      garmentLength: null,
      createdAt: DateTime(2026, 9, 4),
      updatedAt: DateTime(2026, 9, 4),
      deletedAt: null,
    );

    expect(customer.hasMeasurements, isFalse);
    expect(customer.measurements, isEmpty);
  });

  test('خريطة المقاسات تعرض القيم المدخلة فقط', () {
    final customer = Customer(
      id: 2,
      name: 'ريم',
      phone: '',
      notes: '',
      shoulder: 38,
      chest: 92.5,
      waist: 74,
      hips: null,
      sleeveLength: 58,
      garmentLength: 142,
      createdAt: DateTime(2026, 9, 4),
      updatedAt: DateTime(2026, 9, 4),
      deletedAt: null,
    );

    expect(customer.hasMeasurements, isTrue);
    expect(customer.measurements.length, 5);
    expect(customer.measurements['الصدر'], 92.5);
    expect(customer.measurements.containsKey('الورك'), isFalse);
  });
}
