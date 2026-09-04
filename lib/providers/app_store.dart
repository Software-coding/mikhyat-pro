import 'package:flutter/foundation.dart';
import '../data/app_database.dart';
import '../models/customer.dart';
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
  List<Customer> customers = const [];
  List<Piece> recentPieces = const [];
  List<Withdrawal> recentWithdrawals = const [];
  ReportData? currentWeek;
  Map<String, int> totals = const {'customers': 0, 'pieces': 0, 'withdrawals': 0, 'revenue': 0};
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
        db.customers(limit: 500),
        db.pieces(limit: 8),
        db.withdrawals(limit: 8),
        reports.week(),
        db.allTimeTotals(),
        db.trashCount(),
      ]);
      customers = result[0] as List<Customer>;
      recentPieces = result[1] as List<Piece>;
      recentWithdrawals = result[2] as List<Withdrawal>;
      currentWeek = result[3] as ReportData;
      totals = result[4] as Map<String, int>;
      trashCount = result[5] as int;
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
    int? customerId,
    required String description,
    required int quantity,
    required int basePrice,
    required List<PieceModification> modifications,
  }) async {
    await db.savePiece(
      id: id,
      customerId: customerId,
      description: description,
      quantity: quantity,
      basePrice: basePrice,
      modifications: modifications,
    );
    await refresh();
  }

  Future<void> saveCustomer({
    int? id,
    required String name,
    required String phone,
    required String notes,
    double? shoulder,
    double? chest,
    double? waist,
    double? hips,
    double? sleeveLength,
    double? garmentLength,
  }) async {
    await db.saveCustomer(
      id: id,
      name: name,
      phone: phone,
      notes: notes,
      shoulder: shoulder,
      chest: chest,
      waist: waist,
      hips: hips,
      sleeveLength: sleeveLength,
      garmentLength: garmentLength,
    );
    await refresh();
  }

  Future<void> archiveCustomer(int id) async {
    await db.archiveCustomer(id);
    await refresh();
  }

  Future<void> restoreCustomer(int id) async {
    await db.restoreCustomer(id);
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
