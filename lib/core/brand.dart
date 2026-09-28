/// The product name is never hard-coded anywhere else. Mirrors the devotee
/// app's `Brand` and the backend's `config/brand.php`; override at build time
/// with `--dart-define=BRAND_NAME=...`.
class Brand {
  Brand._();

  static const String name = String.fromEnvironment('BRAND_NAME', defaultValue: 'Darshan Saathi');

  static const String appName = String.fromEnvironment('TRUST_APP_NAME', defaultValue: 'Temple Trust');

  static const String tagline = 'Manage your temple on $name';

  static const String supportEmail = String.fromEnvironment('BRAND_SUPPORT_EMAIL', defaultValue: 'support@darshansaathi.com');

  /// Base URL of the Laravel API, without the `/api/v1` suffix. The same
  /// server as the devotee app and the temple portal.
  static const String defaultApiBase = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://temple.darshansaathi.com');
}
