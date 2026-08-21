import 'package:flutter_test/flutter_test.dart';
import 'package:mikhyat_pro/models/piece.dart';
import 'package:mikhyat_pro/models/report_data.dart';
import 'package:mikhyat_pro/models/withdrawal.dart';
import 'package:mikhyat_pro/services/report_service.dart';

void main() {
  test('الأسبوع يبدأ السبت وينتهي الجمعة', () {
    final bounds = ReportService.weekBounds(anchor: DateTime(2026, 8, 21)); // الجمعة
    expect(bounds.start, DateTime(2026, 8, 15));
    expect(bounds.end, DateTime(2026, 8, 21));
  });

  test('الصافي المتعادل له حالة مستقلة', () {
    final now = DateTime(2026, 8, 21);
    final report = ReportData(
      start: now,
      end: now,
      pieces: [Piece(id: 1, description: '', quantity: 1, basePrice: 500, createdAt: now, updatedAt: now, deletedAt: null, modifications: const [])],
      withdrawals: [Withdrawal(id: 1, amount: 500, note: '', createdAt: now, updatedAt: now, deletedAt: null)],
      daily: const [],
    );
    expect(report.net, 0);
    expect(report.status, FinancialStatus.balanced);
    expect(report.expenseRatio, 100);
  });

  test('إذا الإيراد صفر لا نعرض نسبة مصروفات وهمية', () {
    final now = DateTime(2026, 8, 21);
    final report = ReportData(
      start: now,
      end: now,
      pieces: const [],
      withdrawals: [Withdrawal(id: 1, amount: 100, note: '', createdAt: now, updatedAt: now, deletedAt: null)],
      daily: const [],
    );
    expect(report.expenseRatio, isNull);
  });

  test('حدود الشهر صحيحة عند الانتقال بين السنوات', () {
  final bounds = ReportService.monthBounds(anchor: DateTime(2026, 1, 15), offset: -1);
  expect(bounds.start, DateTime(2025, 12, 1));
  expect(bounds.end, DateTime(2025, 12, 31));
});

test('تجميع الشهر إلى أسابيع يحترم السبت كبداية', () {
  final start = DateTime(2026, 8, 1); // السبت
  final daily = List.generate(10, (i) => DailySummary(
    date: start.add(Duration(days: i)),
    pieces: 1,
    jobs: 1,
    revenue: 100,
    expenses: 10,
  ));
  final report = ReportData(start: start, end: DateTime(2026, 8, 10), pieces: const [], withdrawals: const [], daily: daily);
  final weeks = ReportService.aggregateWeeks(report);
  expect(weeks.length, 2);
  expect(weeks.first.date, DateTime(2026, 8, 1));
  expect(weeks.first.revenue, 700);
  expect(weeks.last.date, DateTime(2026, 8, 8));
  expect(weeks.last.revenue, 300);
});

test('إحصاء التعديلات يجمع العدد والإيراد لكل اسم', () {
  final now = DateTime(2026, 8, 21);
  final report = ReportData(
    start: now,
    end: now,
    pieces: [
      Piece(
        id: 1,
        description: '',
        quantity: 3,
        basePrice: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        modifications: const [PieceModification(name: 'الطول', pricePerPiece: 500, appliedQuantity: 3)],
      ),
      Piece(
        id: 2,
        description: '',
        quantity: 2,
        basePrice: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        modifications: const [PieceModification(name: 'الطول', pricePerPiece: 250, appliedQuantity: 2)],
      ),
    ],
    withdrawals: const [],
    daily: const [],
  );
  expect(report.topModifications.first.name, 'الطول');
  expect(report.topModifications.first.count, 5);
  expect(report.topModifications.first.revenue, 2000);
});

test('المتوسطات وأعلى القيم تُحسب بصورة صحيحة', () {
  final now = DateTime(2026, 8, 21);
  final report = ReportData(
    start: now,
    end: now,
    pieces: [
      Piece(id: 1, description: '', quantity: 2, basePrice: 500, createdAt: now, updatedAt: now, deletedAt: null, modifications: const []),
      Piece(id: 2, description: '', quantity: 1, basePrice: 900, createdAt: now, updatedAt: now, deletedAt: null, modifications: const []),
    ],
    withdrawals: [
      Withdrawal(id: 1, amount: 100, note: '', createdAt: now, updatedAt: now, deletedAt: null),
      Withdrawal(id: 2, amount: 300, note: '', createdAt: now, updatedAt: now, deletedAt: null),
    ],
    daily: const [],
  );
  expect(report.revenue, 1900);
  expect(report.pieceCount, 3);
  expect(report.highestPiece, 1000);
  expect(report.highestWithdrawal, 300);
  expect(report.averageWithdrawal, 200);
});
}
