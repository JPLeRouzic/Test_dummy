import 'dart:convert';
import 'dart:io';

import 'package:anatomo/atlas/atlas_controller.dart';
import 'package:anatomo/body_manifest.dart';
import 'package:anatomo/selection.dart';
import 'package:flutter_test/flutter_test.dart';

/// All mixes of the inner layers (letters in file order) plus the skin.
List<String> allMixes() {
  const letters = ['o', 'b', 'm', 'v', 'n'];
  final out = <String>['s'];
  for (var mask = 1; mask < 32; mask++) {
    final b = StringBuffer();
    for (var i = 0; i < letters.length; i++) {
      if (mask & (1 << i) != 0) b.write(letters[i]);
    }
    out.add(b.toString());
  }
  return out;
}

BodyManifest readAtlas(String sex) => BodyManifest.parse(
      sex,
      jsonDecode(File('assets/atlas/$sex/atlas.json').readAsStringSync())
          as Map<String, dynamic>,
    );

void main() {
  for (final sex in ['male', 'female']) {
    test('$sex 2D pictures and tap maps all exist', () {
      final m = readAtlas(sex);
      expect(m.pictureSizes.keys.toSet(), {'front', 'back', 'side'});
      for (final view in ['front', 'back', 'side']) {
        for (final mix in allMixes()) {
          final base = 'assets/atlas/$sex/$view/$mix';
          expect(File('$base.webp').existsSync(), isTrue, reason: '$base.webp');
          expect(File('$base.ids.png').existsSync(), isTrue, reason: '$base.ids.png');
        }
      }
    });

    test('$sex atlas parts match the 3D pack, in the same order', () {
      final atlas = readAtlas(sex);
      final pack = jsonDecode(
        File('pack/models/$sex/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final fields = (pack['fields'] as List).cast<String>();
      final idAt = fields.indexOf('id');
      final rows = pack['parts'] as List;
      expect(atlas.parts.length, rows.length);
      for (var i = 0; i < rows.length; i++) {
        expect(atlas.parts[i].id, '${(rows[i] as List)[idAt]}');
        expect(atlas.parts[i].index, i);
      }
      expect(atlas.parts.where((p) => p.visible).length, greaterThan(100));
    });
  }

  group('AtlasController', () {
    late AtlasController c;
    final selected = <ViewerSelection>[];
    var cleared = 0;
    Map<String, bool>? reported;

    setUp(() {
      selected.clear();
      cleared = 0;
      reported = null;
      c = AtlasController(
        onSelect: selected.add,
        onClear: () => cleared++,
        onLayers: (l) => reported = l,
        layers: const {
          'organs': true,
          'bones': true,
          'muscles': false,
          'nerves': false,
          'vessels': false,
          'skin': true,
        },
      );
      c.setManifest(readAtlas('male'));
    });

    test('picture name follows the layers', () {
      expect(c.mix, 'ob');
      expect(c.skinOn, isTrue);
      c.setLayers(const {'muscles': true, 'organs': false});
      expect(c.mix, 'bm');
    });

    test('selecting a hidden layer switches it on', () {
      expect(c.selectKey('biceps'), isTrue);
      expect(reported?['muscles'], isTrue);
      expect(c.mix, 'obm');
      expect(selected.single.key, 'biceps');
      expect(c.selected, isNotEmpty);
    });

    test('switching the layer of the selection off clears it', () {
      c.selectKey('heart');
      expect(selected.single.whole, isTrue);
      c.setLayers(const {'organs': false});
      expect(c.selected, isEmpty);
      expect(cleared, 1);
    });

    test('tapping the empty stage clears the selection', () {
      c.selectKey('heart');
      c.tapEmpty();
      expect(c.selected, isEmpty);
      expect(cleared, 1);
    });
  });
}
