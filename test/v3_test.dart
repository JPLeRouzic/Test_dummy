import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:anatomo/body_manifest.dart';
import 'package:anatomo/content.dart';
import 'package:anatomo/languages.dart';
import 'package:anatomo/quiz.dart';
import 'package:anatomo/screens/learn_screen.dart';
import 'package:anatomo/screens/quiz_screen.dart';
import 'package:anatomo/settings.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

BodyContent _load(String lang) {
  final parts = <String, PartContent>{};
  final systems = <String, String>{};
  for (final file in ['a', 'b']) {
    final data = _json('assets/content/${lang}_$file.json');
    (data['systems'] as Map).forEach((k, v) => systems['$k'] = '$v');
    (data['parts'] as Map<String, dynamic>).forEach((k, v) {
      parts[k] = PartContent.fromJson(v as Map<String, dynamic>);
    });
  }
  final where = <String, String>{};
  (_json('assets/content/${lang}_w.json')['where'] as Map)
      .forEach((k, v) => where['$k'] = '$v');
  return BodyContent(parts, systems, where);
}

BodyManifest _manifest(String sex) =>
    BodyManifest.parse(sex, _json('assets/atlas/$sex/atlas.json'));

void main() {
  final english = _load('en');

  test('every part has a "where it is" text in every language', () {
    for (final lang in kLanguages) {
      final c = _load(lang.code);
      expect(c.where.keys.toSet(), english.parts.keys.toSet(), reason: lang.code);
      for (final text in c.where.values) {
        expect(text.trim(), isNotEmpty, reason: lang.code);
      }
    }
  });

  test('"works with" links point to real parts', () {
    final links = _json('assets/content/links.json');
    for (final entry in links.entries) {
      expect(english.parts.containsKey(entry.key), isTrue, reason: entry.key);
      for (final other in entry.value as List) {
        expect(english.parts.containsKey(other), isTrue, reason: '$other');
      }
    }
  });

  test('organ of the day is an organ and changes day by day', () {
    final m = _manifest('male');
    final a = organOfTheDay(m, english, DateTime(2026, 10, 28));
    final b = organOfTheDay(m, english, DateTime(2026, 10, 29));
    expect(a, isNotNull);
    expect(m.keyLayers[a], 'organs');
    expect(a, isNot(b));
    expect(organOfTheDay(m, english, DateTime(2026, 10, 28, 23, 59)), a);
  });

  test('quiz modes give 10 questions', () {
    final m = _manifest('female');
    final keys = quizPictureKeys(m);
    expect(keys, isNotEmpty);
    for (var round = 0; round < 10; round++) {
      final mixed = buildQuiz(english, Random(round), pictureKeys: keys);
      expect(mixed.length, 10);
      expect(mixed.where((q) => q.kind == QuizKind.picture), isNotEmpty);
      for (final q in mixed) {
        expect(q.options.toSet().length, 4);
        expect(q.key, isNotEmpty);
      }
      final systems = buildQuiz(english, Random(round), systemsOnly: true);
      expect(systems.length, 10);
      expect(systems.every((q) => q.kind == QuizKind.system), isTrue);
      final find = buildFindQuiz(english, keys, Random(round));
      expect(find.length, 10);
      expect(find.every((q) => keys.contains(q.key)), isTrue);
    }
  });

  test('text size and studied parts are kept and checked', () {
    final settings = AppSettings.inMemory();
    expect(settings.textScale, 1.0);
    settings.setTextScale(1.2);
    expect(settings.textScale, 1.2);
    settings.setTextScale(3);
    expect(settings.textScale, 1.2);
    settings.markStudied('heart');
    settings.markStudied('heart');
    expect(settings.studied, {'heart'});
  });
}
