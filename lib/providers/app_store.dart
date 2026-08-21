import 'package:flutter/foundation.dart';
import '../data/app_database.dart';
import '../models/piece.dart';
import '../models/report_data.dart';
import '../models/withdrawal.dart';
import '../services/report_service.dart';

class AppStore extends ChangeNotifier {
  AppStore({AppDatabase? database})
      : db = database ?? AppDatabase.instance,
        reports = ReportService(database ?? AppDatabase.instance);

  final AppDatabase db;
  final ReportService reports;

  bool loading = true;
  String? error;
  List<Piece> recentPieces = const [];
  List<Withdrawal> recentWithdrawals = const [];
  ReportData? currentWeek;
  Map<String, int> totals = const {'pieces': 0, 'withdrawals': 0, 'revenue': 0};
  int trashCount = 0;
  int revision = 0;

  Future<void> initialize() async {
    try {
      await db.createDailyBackupIfNeeded();
    } catch (_) {
      // فشل النسخ الاحتياطي لا يمنع فتح التطبيق.
    }
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await Future.wait<dynamic>([
        db.pieces(limit: 8),
        db.withdrawals(limit: 8),
        reports.week(),
        db.allTimeTotals(),
        db.trashCount(),
      ]);
      recentPieces = result[0] as List<Piece>;
      recentWithdrawals = result[1] as List<Withdrawal>;
      currentWeek = result[2] as ReportData;
      totals = result[3] as Map<String, int>;
      trashCount = result[4] as int;
      revision++;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> savePiece({
    int? id,
    required String description,
    required int quantity,
    required int basePrice,
    required List<PieceModification> modifications,
  }) async {
    await db.savePiece(
      id: id,
      description: description,
      quantity: quantity,
      basePrice: basePrice,
      modifications: modifications,
    );
    await refresh();
  }

  Future<void> saveWithdrawal({int? id, required int amount, required String note}) async {
    await db.saveWithdrawal(id: id, amount: amount, note: note);
    await refresh();
  }

  Future<void> deletePiece(int id) async {
    await db.softDeletePiece(id);
    await refresh();
  }

  Future<void> deleteWithdrawal(int id) async {
    await db.softDeleteWithdrawal(id);
    await refresh();
  }

  Future<void> restorePiece(int id) async {
    await db.restorePiece(id);
    await refresh();
  }

  Future<void> restoreWithdrawal(int id) async {
    await db.restoreWithdrawal(id);
    await refresh();
  }
}
