import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/local_db.dart';

String _newClientId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Offline-first answer log.
///
/// Every answer is written to SQLite first (so it is never lost), then sent
/// to the server in batches. Each answer has a `client_id`, so the server can
/// ignore duplicates if a request succeeds but the response is lost.
/// The server stays the source of truth for the spaced-repetition schedule.
class AnswerQueue {
  AnswerQueue(this._dio, this._db);

  final Dio _dio;
  final LocalDb _db;
  bool _syncing = false;

  Future<void> record({
    required int caseId,
    required Set<int> selected,
    required int durationMs,
  }) async {
    final db = await _db.database;
    await db.insert('pending_answers', {
      'client_id': _newClientId(),
      'case_id': caseId,
      'selected': jsonEncode(selected.toList()..sort()),
      'answered_at': DateTime.now().toUtc().toIso8601String(),
      'duration_ms': durationMs,
    });
    unawaited(sync()); // best effort, fine if offline
  }

  Future<int> pendingCount() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM pending_answers');
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<Set<int>> pendingCaseIds() async {
    final db = await _db.database;
    final rows = await db.query('pending_answers', columns: ['case_id']);
    return {for (final r in rows) r['case_id'] as int};
  }

  /// Sends pending answers. Returns true when the queue is empty afterwards.
  Future<bool> sync() async {
    if (_syncing) return false;
    _syncing = true;
    try {
      final db = await _db.database;
      while (true) {
        final rows = await db.query(
          'pending_answers',
          orderBy: 'answered_at ASC',
          limit: 50,
        );
        if (rows.isEmpty) return true;

        final res = await _dio.post<Map<String, dynamic>>(
          '/review/answers',
          data: {
            'answers': [
              for (final r in rows)
                {
                  'client_id': r['client_id'],
                  'case_id': r['case_id'],
                  'selected_choice_ids': jsonDecode(r['selected'] as String),
                  'answered_at': r['answered_at'],
                  'duration_ms': r['duration_ms'],
                },
            ],
          },
        );

        // `accepted` = stored (or already known); `rejected` = will never be
        // accepted (e.g. case deleted), so drop them instead of retrying forever.
        final data = res.data ?? const <String, dynamic>{};
        final done = <String>{
          ...((data['accepted'] as List?) ?? const []).cast<String>(),
          ...((data['rejected'] as List?) ?? const []).cast<String>(),
        };
        if (done.isEmpty) return false; // avoid an infinite loop
        await db.delete(
          'pending_answers',
          where: 'client_id IN (${List.filled(done.length, '?').join(',')})',
          whereArgs: done.toList(),
        );
      }
    } on DioException {
      return false; // offline or server error: retry later
    } finally {
      _syncing = false;
    }
  }
}

final answerQueueProvider = Provider<AnswerQueue>(
  (ref) => AnswerQueue(ref.read(dioProvider), ref.read(localDbProvider)),
);
