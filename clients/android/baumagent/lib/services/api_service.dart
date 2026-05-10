import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final StorageService _storage;
  http.Client _client = http.Client();

  ApiService(this._storage);

  Future<http.Client> _getClient() async => _client;

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Uri _uri(String baseUrl, String path, [Map<String, dynamic>? params]) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final uri = Uri.parse('$base$path');
    if (params == null) return uri;
    return uri.replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString())));
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? params]) async {
    final url = await _storage.getUrl();
    final r = await _client.get(_uri(url!, path, params), headers: await _headers());
    _checkStatus(r);
    return jsonDecode(r.body);
  }

  Future<dynamic> _post(String path, [Object? body]) async {
    final url = await _storage.getUrl();
    final r = await _client.post(
      _uri(url!, path),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    _checkStatus(r);
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  Future<void> _delete(String path) async {
    final url = await _storage.getUrl();
    final r = await _client.delete(_uri(url!, path), headers: await _headers());
    _checkStatus(r);
  }

  void _checkStatus(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      String msg;
      try {
        msg = (jsonDecode(r.body) as Map)['detail']?.toString() ?? r.reasonPhrase ?? '';
      } catch (_) {
        msg = r.body;
      }
      throw ApiException(r.statusCode, msg);
    }
  }

  // ── Health (unauthenticated) ──────────────────────────────────────────────

  Future<Map<String, dynamic>> checkHealth(String baseUrl) async {
    final r = await http.get(_uri(baseUrl, 'api/health'));
    _checkStatus(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ── Pairing ───────────────────────────────────────────────────────────────

  Future<PairCompleteResponse> completePairing(
      String baseUrl, String code, String deviceName) async {
    final r = await http.post(
      _uri(baseUrl, 'api/auth/pair/complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'device_name': deviceName}),
    );
    if (!r.isSuccessful) {
      throw ApiException(r.statusCode, 'Pairing failed: ${r.body}');
    }
    return PairCompleteResponse.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Tokens ────────────────────────────────────────────────────────────────

  Future<List<ApiToken>> listTokens() async {
    final data = await _get('api/auth/tokens') as List;
    return data.map((e) => ApiToken.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> revokeToken(String tokenId) => _delete('api/auth/tokens/$tokenId');

  // ── Push ──────────────────────────────────────────────────────────────────

  Future<void> registerPushToken(String platform, String token, String deviceLabel) =>
      _post('api/push/register', {'platform': platform, 'token': token, 'device_label': deviceLabel});

  // ── Tasks ─────────────────────────────────────────────────────────────────

  Future<TaskListResponse> listTasks({int page = 1, int pageSize = 25}) async {
    final data = await _get('api/tasks', {'page': page, 'page_size': pageSize}) as Map<String, dynamic>;
    return TaskListResponse.fromJson(data);
  }

  Future<BaumTask> getTask(String taskId) async {
    final data = await _get('api/tasks/$taskId') as Map<String, dynamic>;
    return BaumTask.fromJson(data);
  }

  Future<BaumTask> createTask({
    required String description,
    String taskType = 'research',
    String llmBackend = 'anthropic',
    String llmModel = 'claude-opus-4-6',
    String repoUrl = '',
    String baseBranch = 'main',
    String? projectId,
    String? targetOs,
    String? difficulty,
  }) async {
    final url = await _storage.getUrl();
    final token = await _storage.getToken();
    final request = http.MultipartRequest('POST', _uri(url!, 'api/tasks'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['description'] = description
      ..fields['task_type'] = taskType
      ..fields['llm_backend'] = llmBackend
      ..fields['llm_model'] = llmModel
      ..fields['repo_url'] = repoUrl
      ..fields['base_branch'] = baseBranch;
    if (projectId != null) request.fields['project_id'] = projectId;
    if (targetOs != null) request.fields['target_os'] = targetOs;
    if (difficulty != null) request.fields['difficulty'] = difficulty;

    final streamed = await request.send();
    final r = await http.Response.fromStream(streamed);
    _checkStatus(r);
    return BaumTask.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<BaumTask> retryTask(String taskId) async {
    final data = await _post('api/tasks/$taskId/retry') as Map<String, dynamic>;
    return BaumTask.fromJson(data);
  }

  Future<void> cancelTask(String taskId) => _post('api/tasks/$taskId/cancel');

  Future<List<ExportFile>> listExports(String taskId) async {
    final data = await _get('api/tasks/$taskId/exports') as List;
    return data.map((e) => ExportFile.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Queue ─────────────────────────────────────────────────────────────────

  Future<QueueStatus> getQueue() async {
    final data = await _get('api/queue') as Map<String, dynamic>;
    return QueueStatus.fromJson(data);
  }

  // ── Projects ──────────────────────────────────────────────────────────────

  Future<List<Project>> listProjects() async {
    final data = await _get('api/projects') as List;
    return data.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── GitNexus ──────────────────────────────────────────────────────────────

  Future<FixTaskResponse> fixHealthScan(String sourceTaskId) async {
    final data = await _post('api/gitnexus/fix', {'source_task_id': sourceTaskId})
        as Map<String, dynamic>;
    return FixTaskResponse.fromJson(data);
  }
}

extension on http.Response {
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}
