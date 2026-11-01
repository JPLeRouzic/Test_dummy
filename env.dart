/// Build-time configuration, e.g.:
/// flutter run \
///   --dart-define=API_BASE_URL=https://staging.example.org/api/v1 \
///   --dart-define=RC_IOS_KEY=appl_xxx --dart-define=RC_ANDROID_KEY=goog_xxx
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Placeholder: adjust to your real API root.
    defaultValue: 'https://padiracinnovation.org/medquest/api/v1',
  );

  // RevenueCat public SDK keys (one per platform). Empty = purchases disabled.
  static const revenueCatIosKey = String.fromEnvironment('RC_IOS_KEY');
  static const revenueCatAndroidKey = String.fromEnvironment('RC_ANDROID_KEY');

  // Required by both stores on the paywall and in settings. Placeholders.
  static const termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://padiracinnovation.org/medquest/terms',
  );
  static const privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://padiracinnovation.org/medquest/privacy',
  );
}
