import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyUrl = 'baum_url';
  static const _keyToken = 'baum_token';
  static const _keyEmail = 'baum_email';
  static const _keyDisplay = 'baum_display';

  Future<bool> hasCredentials() async {
    final token = await _storage.read(key: _keyToken);
    return token != null && token.isNotEmpty;
  }

  Future<void> saveCredentials({
    required String url,
    required String token,
    required String email,
    required String displayName,
  }) async {
    await Future.wait([
      _storage.write(key: _keyUrl, value: url),
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyEmail, value: email),
      _storage.write(key: _keyDisplay, value: displayName),
    ]);
  }

  Future<({String url, String token, String email, String display})> getCredentials() async {
    final results = await Future.wait([
      _storage.read(key: _keyUrl),
      _storage.read(key: _keyToken),
      _storage.read(key: _keyEmail),
      _storage.read(key: _keyDisplay),
    ]);
    return (
      url: results[0] ?? '',
      token: results[1] ?? '',
      email: results[2] ?? '',
      display: results[3] ?? '',
    );
  }

  Future<String?> getUrl() => _storage.read(key: _keyUrl);
  Future<String?> getToken() => _storage.read(key: _keyToken);

  Future<void> clearCredentials() async {
    await Future.wait([
      _storage.delete(key: _keyUrl),
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyEmail),
      _storage.delete(key: _keyDisplay),
    ]);
  }
}
