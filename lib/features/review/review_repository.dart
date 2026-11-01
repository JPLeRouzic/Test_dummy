import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_utils.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/answer_queue.dart';
import '../../quiz/domain/clinical_case.dart';

/// Spaced repetition, client side.
///
/// The SERVER decides which cards are due and when each one comes back.
/// The client only: downloads due cards (with full content, so a session
/// works offline), records answers in the [AnswerQueue], and syncs later.
class ReviewRepository {
  ReviewRepository(this._dio, this._db, this._queue);

  final Dio _dio;
  final LocalDb _db;
  final AnswerQueue _queue;

  /// Cards for a session. Online: fresh from the server (and cached).
  /// Offline: whatever was cached by the last successful fetch.
  Future<List<ClinicalCase>> loadDue({int limit = 20}) async {
    await _queue.sync(); // push old answers first so the server schedule is current
    final pending = await _queue.pendingCaseIds();
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/review/due',
        queryParameters: {'limit': limit},
      );
      final cards = (res.data!['cards'] as List)
          .map((e) => ClinicalCase.fromJson(e as Map<String, dynamic>))
          .where((c) => !pending.contains(c.id)) // answered, not yet synced
          .toList();
      await _replaceLocalCards(cards);
      return cards;
    } on DioException catch (e) {
      if (!isNetworkError(e)) rethrow;
      return _localCards(limit);
    }
  }

  /// Number of cards due today, shown on the review home screen.
  Future<int> dueCount() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/review/summary');
      return res.data!['due_count'] as int;
    } on DioException catch (e) {
      if (!isNetworkError(e)) rethrow;
      final db = await _db.database;
      final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM cards');
      return (rows.first['n'] as int?) ?? 0;
    }
  }

  Future<void> recordAnswer(
    ClinicalCase card,
    Set<int> selected,
    int durationMs,
  ) async {
    await _queue.record(
      caseId: card.id,
      selected: selected,
      durationMs: durationMs,
    );
    final db = await _db.database;
    await db.delete('cards', where: 'case_id = ?', whereArgs: [card.id]);
  }

  Future<void> _replaceLocalCards(List<ClinicalCase> cards) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('cards');
      for (final c in cards) {
        await txn.insert('cards', {'case_id': c.id, 'json': jsonEncode(c.toJson())});
      }
    });
  }

  Future<List<ClinicalCase>> _localCards(int limit) async {
    final db = await _db.database;
    final rows = await db.query('cards', limit: limit);
    return [
      for (final r in rows)
        ClinicalCase.fromJson(
          jsonDecode(r['json'] as String) as Map<String, dynamic>,
        ),
    ];
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(
    ref.read(dioProvider),
    ref.read(localDbProvider),
    ref.read(answerQueueProvider),
  ),
);
