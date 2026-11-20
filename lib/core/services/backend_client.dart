import 'dart:convert';

import 'package:http/http.dart' as http;

import '../keys/key_store.dart';
import '../models/models.dart';

/// Thin client for the optional Python backend's tool endpoints.
class BackendClient {
  BackendClient._();
  static final BackendClient instance = BackendClient._();

  Future<String?> _base() async {
    final value = await KeyStore.instance.read(KeyStoreKeys.backendUrl);
    final base = value?.trim();
    return (base == null || base.isEmpty) ? null : base.replaceAll(RegExp(r'/+$'), '');
  }

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  Future<List<String>?> fetchToolNames() async {
    final base = await _base();
    if (base == null) return null;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .get(Uri.parse('$base/tools'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['tools'] as List? ?? const [];
      return list
          .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Returns stored memory facts, or null when backend is not configured.
  Future<List<String>?> fetchMemory() async {
    final base = await _base();
    if (base == null) return null;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .get(Uri.parse('$base/memory'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['facts'] as List? ?? const [];
      return list
          .map((e) => (e as Map<String, dynamic>)['text']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> addMemory(String text) async {
    final base = await _base();
    if (base == null) return false;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .post(
            Uri.parse('$base/memory'),
            headers: _headers(token),
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Push chat messages to the backend. [replace] clears before appending.
  Future<bool> syncHistory(
    List<Map<String, dynamic>> messages, {
    bool replace = false,
  }) async {
    final base = await _base();
    if (base == null) return false;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .post(
            Uri.parse('$base/history'),
            headers: _headers(token),
            body: jsonEncode({'messages': messages, 'replace': replace}),
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearHistory() async {
    final base = await _base();
    if (base == null) return false;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .delete(Uri.parse('$base/history'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------- Multi-device auth ----------

  /// Register a new device name; returns a device token to save locally.
  Future<String?> registerDevice(String name) async {
    final base = await _base();
    if (base == null) return null;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .post(
            Uri.parse('$base/devices/register'),
            headers: _headers(token),
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['token']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>?> listDevices() async {
    final base = await _base();
    if (base == null) return null;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .get(Uri.parse('$base/devices'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['devices'] as List? ?? const [];
      return list
          .map((e) {
            final d = e as Map<String, dynamic>;
            final active = d['active'] as bool? ?? true;
            return '${d['name'] ?? '?'} ${active ? '' : '(revoked)'}';
          })
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> revokeDevice(String name) async {
    final base = await _base();
    if (base == null) return false;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .post(
            Uri.parse('$base/devices/revoke'),
            headers: _headers(token),
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------- Backup / export / import ----------

  /// Full backup as a JSON string (pretty-printed for sharing/saving).
  Future<String?> exportBackup() async {
    final base = await _base();
    if (base == null) return null;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .get(Uri.parse('$base/export'), headers: _headers(token))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return null;
    }
  }

  /// Restore facts + history from a previously exported JSON string.
  Future<bool> importBackup(String raw) async {
    final base = await _base();
    if (base == null) return false;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final response = await http
          .post(
            Uri.parse('$base/import'),
            headers: _headers(token),
            body: jsonEncode({
              'facts': decoded['facts'] ?? const [],
              'history': decoded['history'] ?? const [],
            }),
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------- Chat summary ----------

  Future<String?> fetchSummary() async {
    final base = await _base();
    if (base == null) return null;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .post(Uri.parse('$base/summary'), headers: _headers(token))
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['summary']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<ToolResult?> execute(ToolCall call, {bool confirmed = false}) async {
    final base = await _base();
    if (base == null) return null;
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    try {
      final response = await http
          .post(
            Uri.parse('$base/execute'),
            headers: _headers(token),
            body: jsonEncode({
              'tool': call.name,
              'args': call.args,
              'confirmed': confirmed,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return ToolResult(
          tool: call.name,
          message: 'Backend error ${response.statusCode}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ToolResult(
        tool: data['tool']?.toString() ?? call.name,
        message: data['message']?.toString() ?? '',
        needsConfirm: data['needs_confirm'] as bool? ?? false,
      );
    } catch (e) {
      return ToolResult(tool: call.name, message: 'Backend issue: $e');
    }
  }
}
