import 'package:anatomo/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNewer', () {
    test('compares versions', () {
      expect(UpdateChecker.isNewer('1.0.1', '1.0.0+1'), isTrue);
      expect(UpdateChecker.isNewer('1.1.0', '1.0.9'), isTrue);
      expect(UpdateChecker.isNewer('2.0.0', '1.9.9+40'), isTrue);
      expect(UpdateChecker.isNewer('1.0.0', '1.0.0+7'), isFalse);
      expect(UpdateChecker.isNewer('0.9.0', '1.0.0'), isFalse);
    });
  });

  group('isTrustedDownload', () {
    test('accepts only this repo on github.com', () {
      expect(
        UpdateChecker.isTrustedDownload(
          'https://github.com/lumio-apps/anatomo/releases/download/v1.1.0/Anatomo-v1.1.0.apk',
        ),
        isTrue,
      );
      expect(
        UpdateChecker.isTrustedDownload(
          'http://github.com/lumio-apps/anatomo/releases/download/v1.1.0/a.apk',
        ),
        isFalse,
      );
      expect(
        UpdateChecker.isTrustedDownload(
          'https://example.com/lumio-apps/anatomo/releases/download/v1/a.apk',
        ),
        isFalse,
      );
      expect(
        UpdateChecker.isTrustedDownload(
          'https://github.com/someone/else/releases/download/v1/a.apk',
        ),
        isFalse,
      );
    });
  });
}
