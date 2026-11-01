import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:anatomo/content.dart';
import 'package:anatomo/quiz.dart';
import 'package:anatomo/settings.dart';

BodyContent _load(String lang) {
  final parts = <String, PartContent>{};
  final systems = <String, String>{};
  for (final file in ['a', 'b']) {
    final data = jsonDecode(
      File('assets/content/${lang}_$file.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    (data['systems'] as Map).forEach((k, v) => systems['$k'] = '$v');
    (data['parts'] as Map<String, dynamic>).forEach((k, v) {
      parts[k] = PartContent.fromJson(v as Map<String, dynamic>);
    });
  }
  return BodyContent(parts, systems);
}

void main() {
  for (final lang in ['en', 'hi', 'ja', 'ar']) {
    test('quiz in $lang has 10 good questions', () {
      final content = _load(lang);
      for (var round = 0; round < 20; round++) {
        final quiz = buildQuiz(content, Random(round));
        expect(quiz.length, 10);
        for (final q in quiz) {
          expect(q.options.length, 4);
          expect(q.options.toSet().length, 4);
          expect(q.answer, inInclusiveRange(0, 3));
          expect(q.subject, isNotEmpty);
        }
      }
    });
  }

  test('favorites and best score are kept', () {
    final settings = AppSettings.inMemory();
    settings.toggleFavorite('heart');
    expect(settings.favorites, {'heart'});
    settings.toggleFavorite('heart');
    expect(settings.favorites, isEmpty);
    settings.setQuizBest(7);
    settings.setQuizBest(4);
    expect(settings.quizBest, 7);
  });
}
