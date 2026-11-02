import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/error/failure.dart';
import '../domain/offline_ticket.dart';

String ticketHash(String code) =>
    sha256.convert(utf8.encode(code.trim())).toString();

class OfflineStore {
  OfflineStore(this.db);
  final Database db;
  static Future<OfflineStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final selected = factory ?? databaseFactory;
    final name =
        path ?? '${await selected.getDatabasesPath()}/fcourt_staff_offline.db';
    final db = await selected.openDatabase(
      name,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE tickets(user_id INTEGER,branch_id INTEGER,date TEXT,booking_id INTEGER,code_hash TEXT,court TEXT,name TEXT,valid_from TEXT,valid_until TEXT,permit TEXT,consumed INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(user_id,branch_id,code_hash))',
          );
          await db.execute(
            'CREATE TABLE snapshots(user_id INTEGER,branch_id INTEGER,date TEXT,generated_at TEXT,PRIMARY KEY(user_id,branch_id))',
          );
          await db.execute(
            'CREATE TABLE outbox(command_key TEXT PRIMARY KEY,user_id INTEGER,branch_id INTEGER,booking_id INTEGER,code_hash TEXT,permit TEXT,occurred_at TEXT,status TEXT NOT NULL DEFAULT \'pending\')',
          );
          await db.execute(
            'CREATE INDEX pending_scope ON outbox(user_id,branch_id,status)',
          );
        },
      ),
    );
    return OfflineStore(db);
  }

  Future<void> replace(OfflineSnapshot snapshot) async {
    final scope = snapshot.scope;
    if (snapshot.tickets.length > 5000) {
      throw const UnknownFailure('Danh sách vé vượt giới hạn');
    }
    await db.transaction((tx) async {
      await tx.delete(
        'tickets',
        where: 'user_id=? AND branch_id=? AND consumed=0',
        whereArgs: [scope.userId, scope.branchId],
      );
      for (final t in snapshot.tickets) {
        await tx.insert('tickets', {
          'user_id': scope.userId,
          'branch_id': scope.branchId,
          'date': scope.date,
          'booking_id': t.bookingId,
          'code_hash': t.hash,
          'court': t.court,
          'name': t.name,
          'valid_from': t.from.toUtc().toIso8601String(),
          'valid_until': t.until.toUtc().toIso8601String(),
          'permit': t.permit,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await tx.insert('snapshots', {
        'user_id': scope.userId,
        'branch_id': scope.branchId,
        'date': scope.date,
        'generated_at': snapshot.generatedAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<OfflineTicket> preview(
    OfflineScope scope,
    String code,
    DateTime now,
  ) async {
    final rows = await db.query(
      'tickets',
      where: 'user_id=? AND branch_id=? AND date=? AND code_hash=?',
      whereArgs: [scope.userId, scope.branchId, scope.date, ticketHash(code)],
    );
    final meta = await db.query(
      'snapshots',
      where: 'user_id=? AND branch_id=? AND date=?',
      whereArgs: [scope.userId, scope.branchId, scope.date],
    );
    if (rows.isEmpty || meta.isEmpty) {
      throw const ServerFailure(
        'Chưa có vé trong dữ liệu đầu ca. Kết nối mạng để kiểm tra.',
        statusCode: 404,
      );
    }
    final row = rows.single;
    final synced = DateTime.parse(meta.single['generated_at'] as String);
    if (now.isBefore(synced.subtract(const Duration(minutes: 1))) ||
        now.difference(synced) > const Duration(hours: 12)) {
      throw const ServerFailure(
        'Dữ liệu đầu ca đã cũ. Cần đồng bộ lại.',
        statusCode: 409,
      );
    }
    if (row['consumed'] == 1) {
      throw const ServerFailure(
        'Vé đã nhận sân trên thiết bị này',
        statusCode: 409,
      );
    }
    final ticket = _ticket(row);
    if (now.isBefore(ticket.from) || !now.isBefore(ticket.until)) {
      throw const ServerFailure(
        'Chưa đến hoặc đã hết giờ nhận sân',
        statusCode: 409,
      );
    }
    return ticket;
  }

  OfflineTicket _ticket(Map<String, Object?> row) => OfflineTicket(
    bookingId: row['booking_id'] as int,
    hash: row['code_hash'] as String,
    court: row['court'] as String,
    name: row['name'] as String,
    from: DateTime.parse(row['valid_from'] as String),
    until: DateTime.parse(row['valid_until'] as String),
    permit: row['permit'] as String,
  );

  Future<int> consume(
    OfflineScope scope,
    String code,
    String key,
    DateTime now,
  ) async {
    final previous = await db.query(
      'outbox',
      where: 'command_key=?',
      whereArgs: [key],
    );
    if (previous.isNotEmpty) {
      final p = previous.single;
      if (p['user_id'] != scope.userId ||
          p['branch_id'] != scope.branchId ||
          p['code_hash'] != ticketHash(code) ||
          p['status'] == 'conflict') {
        throw const ServerFailure(
          'Lệnh không khớp hoặc cần đối soát',
          statusCode: 409,
        );
      }
      return p['booking_id'] as int;
    }
    // Revalidate eligibility before taking the transactional compare-and-set.
    final ticket = await preview(scope, code, now);
    return db.transaction((tx) async {
      final queued =
          Sqflite.firstIntValue(
            await tx.rawQuery('SELECT count(*) FROM outbox WHERE status=?', [
              'pending',
            ]),
          ) ??
          0;
      if (queued >= 5000) {
        throw const UnknownFailure(
          'Hàng đợi đã đầy. Đồng bộ trước khi nhận thêm vé.',
        );
      }
      final previous = await tx.query(
        'outbox',
        where: 'command_key=?',
        whereArgs: [key],
      );
      if (previous.isNotEmpty) {
        final p = previous.single;
        if (p['user_id'] != scope.userId ||
            p['branch_id'] != scope.branchId ||
            p['code_hash'] != ticket.hash) {
          throw const ServerFailure(
            'Lệnh đã thuộc một vé khác',
            statusCode: 409,
          );
        }
        return p['booking_id'] as int;
      }
      final changed = await tx.update(
        'tickets',
        {'consumed': 1},
        where: 'user_id=? AND branch_id=? AND code_hash=? AND consumed=0',
        whereArgs: [scope.userId, scope.branchId, ticket.hash],
      );
      if (changed != 1) {
        throw const ServerFailure(
          'Vé đã nhận sân trên thiết bị này',
          statusCode: 409,
        );
      }
      await tx.insert('outbox', {
        'command_key': key,
        'user_id': scope.userId,
        'branch_id': scope.branchId,
        'booking_id': ticket.bookingId,
        'code_hash': ticket.hash,
        'permit': ticket.permit,
        'occurred_at': now.toUtc().toIso8601String(),
      });
      return ticket.bookingId;
    });
  }

  Future<List<Map<String, Object?>>> pending(OfflineScope scope) => db.query(
    'outbox',
    where: 'user_id=? AND branch_id=? AND status=?',
    whereArgs: [scope.userId, scope.branchId, 'pending'],
    orderBy: 'occurred_at',
    limit: 50,
  );
  Future<int> countPending(OfflineScope scope) async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT count(*) FROM outbox WHERE user_id=? AND branch_id=? AND status=?',
          [scope.userId, scope.branchId, 'pending'],
        ),
      ) ??
      0;
  Future<void> finish(String key, {bool conflict = false}) => db.update(
    'outbox',
    {'status': conflict ? 'conflict' : 'done', 'permit': null},
    where: 'command_key=? AND status=?',
    whereArgs: [key, 'pending'],
  );
  Future<int> conflicts(OfflineScope scope) async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT count(*) FROM outbox WHERE user_id=? AND branch_id=? AND status=?',
          [scope.userId, scope.branchId, 'conflict'],
        ),
      ) ??
      0;
  Future<List<Map<String, Object?>>> issues(OfflineScope scope) => db.query(
    'outbox',
    columns: ['booking_id', 'occurred_at'],
    where: 'user_id=? AND branch_id=? AND status=?',
    whereArgs: [scope.userId, scope.branchId, 'conflict'],
    orderBy: 'occurred_at DESC',
    limit: 100,
  );
  Future<void> purge(DateTime now) async {
    // Retain pending commands for reconciliation; scrub old ticket PII separately.
    await db.delete(
      'tickets',
      where: 'valid_until < ?',
      whereArgs: [
        now.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
      ],
    );
    await db.delete(
      'outbox',
      where: 'status != ? AND occurred_at < ?',
      whereArgs: [
        'pending',
        now.subtract(const Duration(days: 7)).toUtc().toIso8601String(),
      ],
    );
  }

  Future<void> close() => db.close();
}
