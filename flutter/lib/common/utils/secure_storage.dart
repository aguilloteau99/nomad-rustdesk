import 'dart:developer' as developer;
import '../../models/platform_model.dart';

/// Secure storage utility for Nomad license data
/// Uses LocalConfig as fallback (flutter_secure_storage not in pubspec.yaml)
class NomadSecureStorage {
  static const String _keyLicenseKey = 'nomad-license-key';
  static const String _keyLicenseToken = 'nomad-license-token';
  static const String _keyExpiresAt = 'nomad-expires-at';
  static const String _keyServerUrl = 'nomad-server-url';

  /// Save license data (key, token, expiresAt)
  static Future<void> saveLicenseData(
      String key, String token, String expiresAt) async {
    try {
      await bind.mainSetLocalOption(key: _keyLicenseKey, value: key);
      await bind.mainSetLocalOption(key: _keyLicenseToken, value: token);
      await bind.mainSetLocalOption(key: _keyExpiresAt, value: expiresAt);
      developer.log('Nomad license data saved', name: 'NomadSecureStorage');
    } catch (e) {
      developer.log('Failed to save license data: $e',
          name: 'NomadSecureStorage', error: e);
      rethrow;
    }
  }

  /// Get license key
  static String getLicenseKey() {
    return bind.mainGetLocalOption(key: _keyLicenseKey);
  }

  /// Get license token
  static String getLicenseToken() {
    return bind.mainGetLocalOption(key: _keyLicenseToken);
  }

  /// Get expiration timestamp
  static String getExpiresAt() {
    return bind.mainGetLocalOption(key: _keyExpiresAt);
  }

  /// Get server URL
  static String getServerUrl() {
    final url = bind.mainGetLocalOption(key: _keyServerUrl);
    return url.isEmpty ? 'https://nomadrust.dev' : url;
  }

  /// Set server URL
  static Future<void> setServerUrl(String url) async {
    await bind.mainSetLocalOption(key: _keyServerUrl, value: url);
  }

  /// Clear all license data (deactivation)
  static Future<void> clearLicense() async {
    try {
      await bind.mainSetLocalOption(key: _keyLicenseKey, value: '');
      await bind.mainSetLocalOption(key: _keyLicenseToken, value: '');
      await bind.mainSetLocalOption(key: _keyExpiresAt, value: '');
      developer.log('Nomad license data cleared', name: 'NomadSecureStorage');
    } catch (e) {
      developer.log('Failed to clear license data: $e',
          name: 'NomadSecureStorage', error: e);
      rethrow;
    }
  }
}
