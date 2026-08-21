import 'piece.dart';
import 'withdrawal.dart';

enum FinancialStatus { profit, deficit, balanced }

class ModificationStat {
  const ModificationStat({required this.name, required this.count, required this.revenue});
  final String name;
  final int count;
  final int revenue;
}

class DailySummary {
  const DailySummary({required this.date, required this.pieces, required this.jobs, required this.revenue, required this.expenses});
  final DateTime date;
  final int pieces;
  final int jobs;
  final int revenue;
  final int expenses;
  int get net => revenue - expenses;
}

class ReportData {
  const ReportData({
    required this.start,
    required this.end,
    required this.pieces,
    required this.withdrawals,
    required this.daily,
  });

  final DateTime start;
  final DateTime end;
  final List<Piece> pieces;
  final List<Withdrawal> withdrawals;
  final List<DailySummary> daily;

  int get pieceCount => pieces.fold(0, (s, p) => s + p.quantity);
  int get jobsCount => pieces.length;
  int get withdrawalCount => withdrawals.length;
  int get revenue => pieces.fold(0, (s, p) => s + p.total);
  int get baseRevenue => pieces.where((p) => !p.hasModifications).fold(0, (s, p) => s + p.total);
  int get modificationsRevenue => pieces.where((p) => p.hasModifications).fold(0, (s, p) => s + p.total);
  int get modificationUnits => pieces.fold(0, (sum, p) => sum + p.modifications.fold(0, (s, m) => s + m.appliedQuantity));
  List<ModificationStat> get topModifications {
    final map = <String, ModificationStat>{};
    for (final piece in pieces) {
      for (final mod in piece.modifications) {
        final old = map[mod.name];
        map[mod.name] = ModificationStat(
          name: mod.name,
          count: (old?.count ?? 0) + mod.appliedQuantity,
          revenue: (old?.revenue ?? 0) + mod.subtotal,
        );
      }
    }
    final values = map.values.toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : b.revenue.compareTo(a.revenue);
      });
    return values.take(8).toList();
  }
  int get expenses => withdrawals.fold(0, (s, w) => s + w.amount);
  int get net => revenue - expenses;
  int get averagePerPiece => pieceCount == 0 ? 0 : (revenue / pieceCount).round();
  int get averagePerJob => jobsCount == 0 ? 0 : (revenue / jobsCount).round();
  int get averageWithdrawal => withdrawalCount == 0 ? 0 : (expenses / withdrawalCount).round();
  int get highestPiece => pieces.isEmpty ? 0 : pieces.map((e) => e.total).reduce((a, b) => a > b ? a : b);
  int get highestWithdrawal => withdrawals.isEmpty ? 0 : withdrawals.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
  double? get expenseRatio => revenue <= 0 ? null : expenses * 100 / revenue;
  FinancialStatus get status => net > 0 ? FinancialStatus.profit : net < 0 ? FinancialStatus.deficit : FinancialStatus.balanced;
}
