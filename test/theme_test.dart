import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatomo/settings.dart';
import 'package:anatomo/theme.dart';

void main() {
  test('colours follow the mode', () {
    AnatomoColors.use(Brightness.dark);
    final darkBg = AnatomoColors.bg;
    expect(AnatomoColors.isLight, isFalse);
    AnatomoColors.use(Brightness.light);
    expect(AnatomoColors.isLight, isTrue);
    expect(AnatomoColors.bg, isNot(darkBg));
    AnatomoColors.use(Brightness.dark);
  });

  test('theme choice is kept and checked', () {
    final settings = AppSettings.inMemory();
    expect(settings.theme, 'system');
    settings.setTheme('light');
    expect(settings.theme, 'light');
    settings.setTheme('blue');
    expect(settings.theme, 'light');
  });

  test('graphics quality is kept and checked', () {
    final settings = AppSettings.inMemory();
    expect(settings.quality, 'auto');
    settings.setQuality('low');
    expect(settings.quality, 'low');
    settings.setQuality('ultra');
    expect(settings.quality, 'low');
  });
}
