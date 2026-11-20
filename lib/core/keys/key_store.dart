import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class KeyStoreKeys {
  static const gemini = 'gemini_key';
  static const deepgram = 'deepgram_key';
  static const openrouter = 'openrouter_key';
  static const backendUrl = 'backend_url';
  static const backendToken = 'backend_token';

  /// Gemini setup order: the install doc must be seen before the engine can
  /// be installed. Persisted so the order survives an app restart.
  static const geminiDocSeen = 'gemini_install_doc_seen';
  static const geminiEngineInstalled = 'gemini_engine_installed';
}

class KeyStore {
  KeyStore._();
  static final KeyStore instance = KeyStore._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> save(String key, String value) => _storage.write(key: key, value: value.trim());
  Future<void> remove(String key) => _storage.delete(key: key);
}
