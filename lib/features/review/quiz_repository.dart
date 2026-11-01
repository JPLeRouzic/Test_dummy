import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/network_utils.dart';
import '../../../core/storage/local_db.dart';
import '../domain/clinical_case.dart';

class QuizRepository {
  QuizRepository(this._dio, this._db);

  final Dio _dio;
  final LocalDb _db;

  Future<List<CaseSummary>> listCases({String? category}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/cases',
      queryParameters: {if (category != null) 'category': category},
    );
    return (res.data!['items'] as List)
        .map((e) => CaseSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Network first, cached copy when offline.
  Future<ClinicalCase> getCase(int id) async {
    final db = await _db.database;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/cases/$id');
      await db.insert(
        'cases_cache',
        {'case_id': id, 'json': jsonEncode(res.data)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return ClinicalCase.fromJson(res.data!);
    } on DioException catch (e) {
      if (!isNetworkError(e)) rethrow;
      final rows = await db.query('cases_cache',
          where: 'case_id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) rethrow;
      return ClinicalCase.fromJson(
        jsonDecode(rows.first['json'] as String) as Map<String, dynamic>,
      );
    }
  }
}

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => QuizRepository(ref.read(dioProvider), ref.read(localDbProvider)),
);
