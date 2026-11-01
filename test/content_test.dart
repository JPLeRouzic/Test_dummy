import 'dart:convert';
import 'dart:io';

import 'package:anatomo/languages.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readContent(String lang) {
  final parts = <String, dynamic>{};
  final systems = <String, dynamic>{};
  for (final file in ['a', 'b']) {
    final data = jsonDecode(
      File('assets/content/${lang}_$file.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    systems.addAll((data['systems'] as Map<String, dynamic>?) ?? {});
    parts.addAll((data['parts'] as Map<String, dynamic>?) ?? {});
  }
  return {'parts': parts, 'systems': systems};
}

Set<String> _manifestKeys(String sex) {
  final data = jsonDecode(
    File('pack/models/$sex/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (data['keys'] as Map<String, dynamic>).keys.toSet();
}

void main() {
  final english = _readContent('en');
  final englishParts = english['parts'] as Map<String, dynamic>;
  final englishSystems = english['systems'] as Map<String, dynamic>;

  test('every part of both bodies has English texts', () {
    final keys = {..._manifestKeys('male'), ..._manifestKeys('female')};
    for (final key in keys) {
      expect(englishParts.containsKey(key), isTrue, reason: 'missing $key');
    }
  });

  test('English texts are complete', () {
    englishParts.forEach((key, value) {
      final v = value as Map<String, dynamic>;
      expect((v['name'] as String).isNotEmpty, isTrue, reason: key);
      expect((v['desc'] as String).isNotEmpty, isTrue, reason: key);
      expect((v['good'] as List).isNotEmpty, isTrue, reason: key);
      expect((v['bad'] as List).isNotEmpty, isTrue, reason: key);
      expect(englishSystems.containsKey(v['system']), isTrue, reason: key);
    });
  });

  for (final lang in kLanguages) {
    test('${lang.code} has the same parts as English', () {
      final local = _readContent(lang.code);
      final parts = local['parts'] as Map<String, dynamic>;
      final systems = local['systems'] as Map<String, dynamic>;
      expect(parts.keys.toSet(), englishParts.keys.toSet());
      expect(systems.keys.toSet(), englishSystems.keys.toSet());
      parts.forEach((key, value) {
        final v = value as Map<String, dynamic>;
        final e = englishParts[key] as Map<String, dynamic>;
        expect(v['system'], e['system'], reason: '${lang.code} $key');
        expect((v['good'] as List).length, (e['good'] as List).length,
            reason: '${lang.code} $key good');
        expect((v['bad'] as List).length, (e['bad'] as List).length,
            reason: '${lang.code} $key bad');
        expect((v['facts'] as List).length, (e['facts'] as List).length,
            reason: '${lang.code} $key facts');
      });
    });
  }
}
