import '../data/app_database.dart';
import '../models/report_data.dart';

class ReportService {
  ReportService(this.db);
  final AppDatabase db;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static ({DateTime start, DateTime end}) weekBounds({DateTime? anchor, int offset = 0}) {
    final a = dateOnly(anchor ?? DateTime.now());
    // Dart: Monday=1 ... Sunday=7. Saturday=6.
    final daysSinceSaturday = (a.weekday - DateTime.saturday) % 7;
    final start = a.subtract(Duration(days: daysSinceSaturday)).add(Duration(days: offset * 7));
    return (start: start, end: start.add(const Duration(days: 6)));
  }

  static ({DateTime start, DateTime end}) monthBounds({DateTime? anchor, int offset = 0}) {
    final a = anchor ?? DateTime.now();
    final index = a.year * 12 + (a.month - 1) + offset;
    final year = index ~/ 12;
    final month = index % 12 + 1;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    return (start: start, end: end);
  }

  Future<ReportData> range(DateTime start, DateTime end) async {
    final s = dateOnly(start);
    final e = dateOnly(end);
    if (e.isBefore(s)) throw ArgumentError('تاريخ النهاية يجب أن يكون بعد البداية');
    final pieces = await db.piecesInRange(s, e);
    final withdrawals = await db.withdrawalsInRange(s, e);
    final daily = <DailySummary>[];
    for (var day = s; !day.isAfter(e); day = day.add(const Duration(days: 1))) {
      final dayPieces = pieces.where((p) => _sameDate(p.createdAt, day)).toList();
      final dayWithdrawals = withdrawals.where((w) => _sameDate(w.createdAt, day)).toList();
      daily.add(DailySummary(
        date: day,
        pieces: dayPieces.fold(0, (sum, p) => sum + p.quantity),
        jobs: dayPieces.length,
        revenue: dayPieces.fold(0, (sum, p) => sum + p.total),
        expenses: dayWithdrawals.fold(0, (sum, w) => sum + w.amount),
      ));
    }
    return ReportData(start: s, end: e, pieces: pieces, withdrawals: withdrawals, daily: daily);
  }

  Future<ReportData> week({int offset = 0}) {
    final b = weekBounds(offset: offset);
    return range(b.start, b.end);
  }

  Future<ReportData> month({int offset = 0}) {
    final b = monthBounds(offset: offset);
    return range(b.start, b.end);
  }

  static List<DailySummary> aggregateWeeks(ReportData report) {
    // الأسابيع محاسبيًا من السبت إلى الجمعة، مع قص أول/آخر أسبوع على حدود الشهر.
    final buckets = <DateTime, List<DailySummary>>{};
    for (final day in report.daily) {
      final daysSinceSaturday = (day.date.weekday - DateTime.saturday) % 7;
      final weekStart = dateOnly(day.date.subtract(Duration(days: daysSinceSaturday)));
      buckets.putIfAbsent(weekStart, () => []).add(day);
    }
    final starts = buckets.keys.toList()..sort();
    return starts.map((weekStart) {
      final days = buckets[weekStart]!;
      final visibleStart = weekStart.isBefore(report.start) ? report.start : weekStart;
      return DailySummary(
        date: visibleStart,
        pieces: days.fold(0, (s, d) => s + d.pieces),
        jobs: days.fold(0, (s, d) => s + d.jobs),
        revenue: days.fold(0, (s, d) => s + d.revenue),
        expenses: days.fold(0, (s, d) => s + d.expenses),
      );
    }).toList();
  }

  static bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
