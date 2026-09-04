import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import '../models/customer.dart';
import '../models/piece.dart';
import '../models/withdrawal.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  static const _dbName = 'mikhyat.db';
  static const _version = 6;
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    final path = p.join(base, _dbName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        shoulder REAL,
        chest REAL,
        waist REAL,
        hips REAL,
        sleeve_length REAL,
        garment_length REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE pieces(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL DEFAULT '',
        customer_id INTEGER,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        base_price INTEGER NOT NULL DEFAULT 0 CHECK(base_price >= 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE piece_modifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        piece_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price_per_piece INTEGER NOT NULL DEFAULT 500 CHECK(price_per_piece >= 0),
        applied_quantity INTEGER NOT NULL CHECK(applied_quantity > 0),
        FOREIGN KEY(piece_id) REFERENCES pieces(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE withdrawals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL CHECK(amount > 0),
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await _indexes(db);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 5) {
      if (oldVersion < 6) {
        await _upgradeToV6(db);
      }
      await _indexes(db);
      return;
    }

    // ترقية آمنة من قواعد الإصدارات القديمة: نقرأ البيانات أولًا ثم نعيد بناء
    // الجداول وفق بنية V5 (أموال Integer + سلة محذوفات + عدد لكل تعديل).
    final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
        .map((e) => e['name']?.toString()).whereType<String>().toSet();
    final pieces = tables.contains('pieces') ? await db.query('pieces') : <Map<String, Object?>>[];
    final mods = tables.contains('piece_modifications') ? await db.query('piece_modifications') : <Map<String, Object?>>[];
    final withdrawals = tables.contains('withdrawals') ? await db.query('withdrawals') : <Map<String, Object?>>[];
    final pieceQuantity = <int, int>{
      for (final row in pieces)
        if (row['id'] != null) _asInt(row['id'], 0): _asInt(row['quantity'], 1).clamp(1, 999999).toInt(),
    };

    await db.execute('PRAGMA foreign_keys = OFF');
    await db.execute('DROP TABLE IF EXISTS piece_modifications_new');
    await db.execute('DROP TABLE IF EXISTS pieces_new');
    await db.execute('DROP TABLE IF EXISTS withdrawals_new');
    await db.execute('''
      CREATE TABLE pieces_new(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL DEFAULT '',
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        base_price INTEGER NOT NULL DEFAULT 0 CHECK(base_price >= 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE piece_modifications_new(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        piece_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price_per_piece INTEGER NOT NULL DEFAULT 500 CHECK(price_per_piece >= 0),
        applied_quantity INTEGER NOT NULL CHECK(applied_quantity > 0),
        FOREIGN KEY(piece_id) REFERENCES pieces_new(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE withdrawals_new(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL CHECK(amount > 0),
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    for (final row in pieces) {
      final id = _asInt(row['id'], 0);
      if (id <= 0) continue;
      final created = _asDateText(row['created_at']);
      await db.insert('pieces_new', {
        'id': id,
        'description': _truncate(row['description'], 300),
        'quantity': _asInt(row['quantity'], 1).clamp(1, 999999).toInt(),
        'base_price': _asInt(row['base_price'], 0).clamp(0, 1 << 62).toInt(),
        'created_at': created,
        'updated_at': _asDateText(row['updated_at'], fallback: created),
        'deleted_at': row.containsKey('deleted_at') ? row['deleted_at']?.toString() : null,
      });
    }
    for (final row in mods) {
      final pieceId = _asInt(row['piece_id'], 0);
      if (!pieceQuantity.containsKey(pieceId)) continue;
      final maxQty = pieceQuantity[pieceId]!;
      final applied = row.containsKey('applied_quantity') ? _asInt(row['applied_quantity'], maxQty) : maxQty;
      await db.insert('piece_modifications_new', {
        if (_asInt(row['id'], 0) > 0) 'id': _asInt(row['id'], 0),
        'piece_id': pieceId,
        'name': _truncate(row['name'] ?? 'تعديل', 120),
        'price_per_piece': _asInt(row['price_per_piece'], 500).clamp(0, 1 << 62).toInt(),
        'applied_quantity': applied.clamp(1, maxQty).toInt(),
      });
    }
    for (final row in withdrawals) {
      final id = _asInt(row['id'], 0);
      if (id <= 0) continue;
      final created = _asDateText(row['created_at']);
      await db.insert('withdrawals_new', {
        'id': id,
        'amount': _asInt(row['amount'], 1).clamp(1, 1 << 62).toInt(),
        'note': _truncate(row['note'], 300),
        'created_at': created,
        'updated_at': _asDateText(row['updated_at'], fallback: created),
        'deleted_at': row.containsKey('deleted_at') ? row['deleted_at']?.toString() : null,
      });
    }

    await db.execute('DROP TABLE IF EXISTS piece_modifications');
    await db.execute('DROP TABLE IF EXISTS pieces');
    await db.execute('DROP TABLE IF EXISTS withdrawals');
    await db.execute('ALTER TABLE pieces_new RENAME TO pieces');
    await db.execute('ALTER TABLE piece_modifications_new RENAME TO piece_modifications');
    await db.execute('ALTER TABLE withdrawals_new RENAME TO withdrawals');
    await db.execute('PRAGMA foreign_keys = ON');
    if (newVersion >= 6) {
      await _upgradeToV6(db);
    }
    await _indexes(db);
  }

  Future<void> _upgradeToV6(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        shoulder REAL,
        chest REAL,
        waist REAL,
        hips REAL,
        sleeve_length REAL,
        garment_length REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    final columns = (await db.rawQuery('PRAGMA table_info(pieces)'))
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toSet();
    if (!columns.contains('customer_id')) {
      await db.execute(
        'ALTER TABLE pieces ADD COLUMN customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL',
      );
    }
  }

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? fallback;
  }


  static String _truncate(Object? value, int maxLength) {
    final text = value?.toString() ?? '';
    return text.length <= maxLength ? text : text.substring(0, maxLength);
  }

  static String _asDateText(Object? value, {String? fallback}) {
    final raw = value?.toString().trim();
    if (raw != null && raw.isNotEmpty) {
      final normalized = raw.replaceFirst(' ', 'T');
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) return parsed.toIso8601String();
    }
    return fallback ?? DateTime.now().toIso8601String();
  }

  Future<void> _indexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pieces_active_created ON pieces(deleted_at, created_at DESC, id DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_withdrawals_active_created ON withdrawals(deleted_at, created_at DESC, id DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_piece_mod_piece ON piece_modifications(piece_id, id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_piece_description ON pieces(description)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pieces_customer ON pieces(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_active_name ON customers(deleted_at, name, id DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_withdrawal_note ON withdrawals(note)');
  }

  Future<Map<int, List<PieceModification>>> _modsMap(DatabaseExecutor db, List<int> pieceIds) async {
    if (pieceIds.isEmpty) return const {};
    final placeholders = List.filled(pieceIds.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT * FROM piece_modifications WHERE piece_id IN ($placeholders) ORDER BY piece_id, id',
      pieceIds,
    );
    final map = <int, List<PieceModification>>{};
    for (final r in rows) {
      final pieceId = r['piece_id'] as int;
      map.putIfAbsent(pieceId, () => []).add(PieceModification(
        id: r['id'] as int,
        name: r['name'] as String,
        pricePerPiece: r['price_per_piece'] as int,
        appliedQuantity: r['applied_quantity'] as int,
      ));
    }
    return map;
  }

  Future<Map<int, String>> _customerNamesMap(DatabaseExecutor db, List<int> customerIds) async {
    if (customerIds.isEmpty) return const {};
    final placeholders = List.filled(customerIds.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT id, name FROM customers WHERE id IN ($placeholders)',
      customerIds,
    );
    return {
      for (final row in rows)
        if (row['id'] is int && row['name'] is String) row['id'] as int: row['name'] as String,
    };
  }

  Future<List<Piece>> _piecesFromRows(DatabaseExecutor db, List<Map<String, Object?>> rows) async {
    final ids = rows.map((r) => r['id'] as int).toList();
    final mods = await _modsMap(db, ids);
    final customerIds = rows.map((r) => r['customer_id'] as int?).whereType<int>().toSet().toList();
    final customerNames = await _customerNamesMap(db, customerIds);
    return rows.map((r) {
      final id = r['id'] as int;
      final customerId = r['customer_id'] as int?;
      return Piece(
        id: id,
        description: (r['description'] as String?) ?? '',
        customerId: customerId,
        customerName: customerId == null ? null : customerNames[customerId],
        quantity: r['quantity'] as int,
        basePrice: r['base_price'] as int,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
        deletedAt: r['deleted_at'] == null ? null : DateTime.parse(r['deleted_at'] as String),
        modifications: mods[id] ?? const [],
      );
    }).toList();
  }

  Future<List<Piece>> pieces({String query = '', bool deleted = false, int? limit, int? offset}) async {
    final db = await database;
    final where = <String>['deleted_at IS ${deleted ? 'NOT ' : ''}NULL'];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add(
        '(description LIKE ? '
        'OR EXISTS(SELECT 1 FROM piece_modifications pm WHERE pm.piece_id=pieces.id AND pm.name LIKE ?) '
        'OR EXISTS(SELECT 1 FROM customers c WHERE c.id=pieces.customer_id AND (c.name LIKE ? OR c.phone LIKE ?)))',
      );
      final q = '%${query.trim()}%';
      args.addAll([q, q, q, q]);
    }
    final rows = await db.query(
      'pieces',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'datetime(created_at) DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return _piecesFromRows(db, rows);
  }

  Future<List<Piece>> piecesInRange(DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.query(
      'pieces',
      where: 'deleted_at IS NULL AND date(created_at) BETWEEN date(?) AND date(?)',
      whereArgs: [_dateOnly(start), _dateOnly(end)],
      orderBy: 'datetime(created_at) ASC, id ASC',
    );
    return _piecesFromRows(db, rows);
  }

  Future<int> savePiece({
    int? id,
    int? customerId,
    required String description,
    required int quantity,
    required int basePrice,
    required List<PieceModification> modifications,
    DateTime? createdAt,
  }) async {
    if (quantity <= 0) throw ArgumentError('عدد القطع يجب أن يكون أكبر من صفر');
    if (basePrice < 0) throw ArgumentError('السعر لا يمكن أن يكون سالبًا');
    if (modifications.isEmpty && basePrice <= 0) throw ArgumentError('سعر القطعة مطلوب عندما لا توجد تعديلات');
    final normalizedNames = modifications.map((m) => m.name.trim()).toList();
    if (normalizedNames.toSet().length != normalizedNames.length) throw ArgumentError('لا يمكن تكرار نفس التعديل في العملية');
    for (final m in modifications) {
      if (m.name.trim().isEmpty) throw ArgumentError('اسم التعديل مطلوب');
      if (m.pricePerPiece < 0) throw ArgumentError('سعر التعديل غير صالح');
      if (m.appliedQuantity <= 0 || m.appliedQuantity > quantity) throw ArgumentError('عدد القطع للتعديل غير صالح');
    }
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      int pieceId;
      if (id == null) {
        pieceId = await txn.insert('pieces', {
          'description': _truncate(description.trim(), 300),
          'customer_id': customerId,
          'quantity': quantity,
          'base_price': modifications.isEmpty ? basePrice : 0,
          'created_at': (createdAt ?? now).toIso8601String(),
          'updated_at': now.toIso8601String(),
          'deleted_at': null,
        });
      } else {
        final old = await txn.query('pieces', columns: ['created_at'], where: 'id=?', whereArgs: [id], limit: 1);
        if (old.isEmpty) throw StateError('العملية غير موجودة');
        pieceId = id;
        await txn.update('pieces', {
          'description': _truncate(description.trim(), 300),
          'customer_id': customerId,
          'quantity': quantity,
          'base_price': modifications.isEmpty ? basePrice : 0,
          // لا نلمس created_at عند التعديل.
          'updated_at': now.toIso8601String(),
        }, where: 'id=?', whereArgs: [id]);
        await txn.delete('piece_modifications', where: 'piece_id=?', whereArgs: [id]);
      }
      for (final m in modifications) {
        await txn.insert('piece_modifications', {
          'piece_id': pieceId,
          'name': _truncate(m.name.trim(), 120),
          'price_per_piece': m.pricePerPiece,
          'applied_quantity': m.appliedQuantity,
        });
      }
      return pieceId;
    });
  }

  Future<List<Customer>> customers({
    String query = '',
    bool deleted = false,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final where = <String>['deleted_at IS ${deleted ? 'NOT ' : ''}NULL'];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(name LIKE ? OR phone LIKE ? OR notes LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }
    final rows = await db.query(
      'customers',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE ASC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_customerFromRow).toList();
  }

  Customer _customerFromRow(Map<String, Object?> row) => Customer(
        id: row['id'] as int,
        name: row['name'] as String,
        phone: (row['phone'] as String?) ?? '',
        notes: (row['notes'] as String?) ?? '',
        shoulder: (row['shoulder'] as num?)?.toDouble(),
        chest: (row['chest'] as num?)?.toDouble(),
        waist: (row['waist'] as num?)?.toDouble(),
        hips: (row['hips'] as num?)?.toDouble(),
        sleeveLength: (row['sleeve_length'] as num?)?.toDouble(),
        garmentLength: (row['garment_length'] as num?)?.toDouble(),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        deletedAt: row['deleted_at'] == null ? null : DateTime.parse(row['deleted_at'] as String),
      );

  Future<int> saveCustomer({
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
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('اسم العميل مطلوب');

    double? clean(double? value) {
      if (value == null) return null;
      if (value <= 0 || value > 500) throw ArgumentError('قيمة القياس غير صالحة');
      return value;
    }

    final db = await database;
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{
      'name': _truncate(normalizedName, 120),
      'phone': _truncate(phone.trim(), 40),
      'notes': _truncate(notes.trim(), 500),
      'shoulder': clean(shoulder),
      'chest': clean(chest),
      'waist': clean(waist),
      'hips': clean(hips),
      'sleeve_length': clean(sleeveLength),
      'garment_length': clean(garmentLength),
      'updated_at': now,
    };

    if (id == null) {
      return db.insert('customers', {
        ...values,
        'created_at': now,
        'deleted_at': null,
      });
    }

    final changed = await db.update('customers', values, where: 'id=?', whereArgs: [id]);
    if (changed == 0) throw StateError('العميل غير موجود');
    return id;
  }

  Future<void> archiveCustomer(int id) async {
    final db = await database;
    await db.update(
      'customers',
      {'deleted_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> restoreCustomer(int id) async {
    final db = await database;
    await db.update(
      'customers',
      {'deleted_at': null, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<List<Withdrawal>> withdrawals({String query = '', bool deleted = false, int? limit, int? offset}) async {
    final db = await database;
    final where = <String>['deleted_at IS ${deleted ? 'NOT ' : ''}NULL'];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('note LIKE ?');
      args.add('%${query.trim()}%');
    }
    final rows = await db.query(
      'withdrawals',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'datetime(created_at) DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_withdrawalFromRow).toList();
  }

  Future<List<Withdrawal>> withdrawalsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.query(
      'withdrawals',
      where: 'deleted_at IS NULL AND date(created_at) BETWEEN date(?) AND date(?)',
      whereArgs: [_dateOnly(start), _dateOnly(end)],
      orderBy: 'datetime(created_at) ASC, id ASC',
    );
    return rows.map(_withdrawalFromRow).toList();
  }

  Withdrawal _withdrawalFromRow(Map<String, Object?> r) => Withdrawal(
    id: r['id'] as int,
    amount: r['amount'] as int,
    note: (r['note'] as String?) ?? '',
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
    deletedAt: r['deleted_at'] == null ? null : DateTime.parse(r['deleted_at'] as String),
  );

  Future<int> saveWithdrawal({int? id, required int amount, required String note, DateTime? createdAt}) async {
    if (amount <= 0) throw ArgumentError('مبلغ السحب يجب أن يكون أكبر من صفر');
    final db = await database;
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      return db.insert('withdrawals', {
        'amount': amount,
        'note': _truncate(note.trim(), 300),
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': now,
        'deleted_at': null,
      });
    }
    final changed = await db.update('withdrawals', {
      'amount': amount,
      'note': _truncate(note.trim(), 300),
      // التاريخ الأصلي محفوظ.
      'updated_at': now,
    }, where: 'id=?', whereArgs: [id]);
    if (changed == 0) throw StateError('السحب غير موجود');
    return id;
  }

  Future<void> softDeletePiece(int id) async {
    final db = await database;
    await db.update('pieces', {'deleted_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> softDeleteWithdrawal(int id) async {
    final db = await database;
    await db.update('withdrawals', {'deleted_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> restorePiece(int id) async {
    final db = await database;
    await db.update('pieces', {'deleted_at': null, 'updated_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> restoreWithdrawal(int id) async {
    final db = await database;
    await db.update('withdrawals', {'deleted_at': null, 'updated_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> permanentlyDeletePiece(int id) async {
    final db = await database;
    await db.delete('pieces', where: 'id=?', whereArgs: [id]);
  }

  Future<void> permanentlyDeleteWithdrawal(int id) async {
    final db = await database;
    await db.delete('withdrawals', where: 'id=?', whereArgs: [id]);
  }

  Future<int> trashCount() async {
    final db = await database;
    final c = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers WHERE deleted_at IS NOT NULL')) ?? 0;
    final p = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pieces WHERE deleted_at IS NOT NULL')) ?? 0;
    final w = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM withdrawals WHERE deleted_at IS NOT NULL')) ?? 0;
    return c + p + w;
  }

  Future<File> backupDatabase() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final source = File(db.path);
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory(p.join(dir.path, 'backups'));
    await backups.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    return source.copy(p.join(backups.path, 'mikhyat_backup_$stamp.db'));
  }

  Future<void> exportBackup() async {
    final file = await backupDatabase();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'نسخة احتياطية — مِخيط Pro',
      text: 'احتفظ بهذا الملف في مكان آمن لاستعادة بيانات مِخيط Pro عند الحاجة.',
    );
  }

  Future<void> createDailyBackupIfNeeded() async {
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory(p.join(dir.path, 'backups'));
    await backups.create(recursive: true);
    final prefix = 'mikhyat_auto_${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final noneExists = await backups.list().where((e) => p.basename(e.path).startsWith(prefix)).isEmpty;
    if (!noneExists) return;
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final source = File(db.path);
    await source.copy(p.join(backups.path, '${prefix}_${DateTime.now().millisecondsSinceEpoch}.db'));
    final autoBackups = await backups
        .list()
        .where((e) =>
            e is File &&
            e.path.endsWith('.db') &&
            p.basename(e.path).startsWith('mikhyat_auto_'))
        .cast<File>()
        .toList();
    autoBackups.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final old in autoBackups.skip(14)) {
      try {
        await old.delete();
      } catch (_) {
        // فشل تنظيف نسخة قديمة لا يجب أن يعطّل التطبيق.
      }
    }
  }

  Future<bool> importBackup() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['db']);
    if (result == null || result.files.single.path == null) return false;

    final picked = File(result.files.single.path!);
    final check = await openDatabase(picked.path, readOnly: true);
    try {
      await _validateBackupFile(check);
    } finally {
      await check.close();
    }

    // نحفظ الوضع الحالي أولًا، ثم نغلق الاتصال قبل استبدال الملف.
    final safetyBackup = await backupDatabase();
    final current = await database;
    final currentPath = current.path;
    if (p.equals(p.normalize(picked.absolute.path), p.normalize(File(currentPath).absolute.path))) {
      throw StateError('اختر ملف نسخة احتياطية مختلفًا عن قاعدة البيانات الحالية');
    }

    await current.close();
    _db = null;

    try {
      await _deleteSqliteSidecars(currentPath);
      await picked.copy(currentPath);
      _db = await _open();
      await _validateCurrentSchema(_db!);
      return true;
    } catch (_) {
      // إذا فشلت الاستعادة لأي سبب، نرجع تلقائيًا لنسخة الأمان السابقة.
      try {
        await _db?.close();
      } catch (_) {}
      _db = null;
      await _deleteSqliteSidecars(currentPath);
      await safetyBackup.copy(currentPath);
      _db = await _open();
      rethrow;
    }
  }

  Future<void> _validateBackupFile(Database db) async {
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    final ok = integrity.isNotEmpty &&
        integrity.first.values.first.toString().toLowerCase() == 'ok';
    if (!ok) {
      throw StateError('ملف قاعدة البيانات تالف');
    }

    final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
        .map((e) => e['name']?.toString())
        .whereType<String>()
        .toSet();
    if (!tables.containsAll({'pieces', 'piece_modifications', 'withdrawals'})) {
      throw StateError('ملف النسخة الاحتياطية غير صالح');
    }
  }

  Future<void> _validateCurrentSchema(Database db) async {
    const requiredColumns = <String, Set<String>>{
      'pieces': {
        'id',
        'description',
        'customer_id',
        'quantity',
        'base_price',
        'created_at',
        'updated_at',
        'deleted_at',
      },
      'customers': {
        'id',
        'name',
        'phone',
        'notes',
        'shoulder',
        'chest',
        'waist',
        'hips',
        'sleeve_length',
        'garment_length',
        'created_at',
        'updated_at',
        'deleted_at',
      },
      'piece_modifications': {
        'id',
        'piece_id',
        'name',
        'price_per_piece',
        'applied_quantity',
      },
      'withdrawals': {
        'id',
        'amount',
        'note',
        'created_at',
        'updated_at',
        'deleted_at',
      },
    };

    for (final entry in requiredColumns.entries) {
      final rows = await db.rawQuery('PRAGMA table_info(${entry.key})');
      final columns = rows
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();
      if (!columns.containsAll(entry.value)) {
        throw StateError('بنية النسخة الاحتياطية غير متوافقة: ${entry.key}');
      }
    }
  }

  Future<void> _deleteSqliteSidecars(String databasePath) async {
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('$databasePath$suffix');
      if (await sidecar.exists()) {
        try {
          await sidecar.delete();
        } catch (_) {
          // سيحاول SQLite معالجة الملف إن تعذر حذفه.
        }
      }
    }
  }

  Future<Map<String, int>> allTimeTotals() async {
    final db = await database;
    final pieces = Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(SUM(quantity),0) FROM pieces WHERE deleted_at IS NULL')) ?? 0;
    final customers = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL')) ?? 0;
    final withdrawals = Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(SUM(amount),0) FROM withdrawals WHERE deleted_at IS NULL')) ?? 0;
    final revenue = Sqflite.firstIntValue(await db.rawQuery("""
      SELECT COALESCE(SUM(
        CASE WHEN EXISTS(SELECT 1 FROM piece_modifications pm WHERE pm.piece_id = pieces.id)
          THEN (SELECT COALESCE(SUM(pm2.price_per_piece * pm2.applied_quantity), 0) FROM piece_modifications pm2 WHERE pm2.piece_id = pieces.id)
          ELSE pieces.quantity * pieces.base_price
        END
      ), 0)
      FROM pieces WHERE deleted_at IS NULL
    """)) ?? 0;
    return {'pieces': pieces, 'customers': customers, 'withdrawals': withdrawals, 'revenue': revenue};
  }

  String _dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
