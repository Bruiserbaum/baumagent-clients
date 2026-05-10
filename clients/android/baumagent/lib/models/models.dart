import 'dart:convert';

// ---------------------------------------------------------------------------
// Task
// ---------------------------------------------------------------------------

class BaumTask {
  final String id;
  final String description;
  final String taskType;
  final String status;
  final String llmBackend;
  final String llmModel;
  final String? repoUrl;
  final String? prUrl;
  final int? prNumber;
  final String? outputFile;
  final String? log;
  final int? progressPercent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? projectId;

  const BaumTask({
    required this.id,
    required this.description,
    required this.taskType,
    required this.status,
    required this.llmBackend,
    required this.llmModel,
    this.repoUrl,
    this.prUrl,
    this.prNumber,
    this.outputFile,
    this.log,
    this.progressPercent,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
  });

  bool get isTerminal => status == 'complete' || status == 'failed' || status == 'cancelled';
  bool get isRunning => status == 'running';

  factory BaumTask.fromJson(Map<String, dynamic> j) => BaumTask(
        id: j['id'] as String,
        description: j['description'] as String,
        taskType: j['task_type'] as String,
        status: j['status'] as String,
        llmBackend: j['llm_backend'] as String,
        llmModel: j['llm_model'] as String,
        repoUrl: j['repo_url'] as String?,
        prUrl: j['pr_url'] as String?,
        prNumber: j['pr_number'] as int?,
        outputFile: j['output_file'] as String?,
        log: j['log'] as String?,
        progressPercent: j['progress_percent'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        projectId: j['project_id'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Task list response
// ---------------------------------------------------------------------------

class TaskListResponse {
  final List<BaumTask> items;
  final int total;
  final int page;
  final int pageSize;

  const TaskListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory TaskListResponse.fromJson(Map<String, dynamic> j) => TaskListResponse(
        items: (j['items'] as List).map((e) => BaumTask.fromJson(e as Map<String, dynamic>)).toList(),
        total: j['total'] as int,
        page: j['page'] as int,
        pageSize: j['page_size'] as int,
      );
}

// ---------------------------------------------------------------------------
// Export file
// ---------------------------------------------------------------------------

class ExportFile {
  final String filename;
  final int sizeBytes;
  final String downloadUrl;

  const ExportFile({
    required this.filename,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  String get sizeDisplay {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1048576) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
  }

  factory ExportFile.fromJson(Map<String, dynamic> j) => ExportFile(
        filename: j['filename'] as String,
        sizeBytes: j['size_bytes'] as int,
        downloadUrl: j['download_url'] as String,
      );
}

// ---------------------------------------------------------------------------
// Queue status
// ---------------------------------------------------------------------------

class QueueStatus {
  final List<String> queued;
  final List<String> running;

  const QueueStatus({required this.queued, required this.running});

  factory QueueStatus.fromJson(Map<String, dynamic> j) => QueueStatus(
        queued: List<String>.from(j['queued'] as List),
        running: List<String>.from(j['running'] as List),
      );
}

// ---------------------------------------------------------------------------
// Pair + token
// ---------------------------------------------------------------------------

class PairInitiateResponse {
  final String code;
  final String pairUrl;
  final int expiresInSeconds;

  const PairInitiateResponse({
    required this.code,
    required this.pairUrl,
    required this.expiresInSeconds,
  });

  factory PairInitiateResponse.fromJson(Map<String, dynamic> j) => PairInitiateResponse(
        code: j['code'] as String,
        pairUrl: j['pair_url'] as String,
        expiresInSeconds: j['expires_in_seconds'] as int,
      );
}

class PairCompleteResponse {
  final String token;
  final String userId;
  final String userEmail;
  final String userDisplayName;

  const PairCompleteResponse({
    required this.token,
    required this.userId,
    required this.userEmail,
    required this.userDisplayName,
  });

  factory PairCompleteResponse.fromJson(Map<String, dynamic> j) => PairCompleteResponse(
        token: j['token'] as String,
        userId: j['user_id'] as String,
        userEmail: j['user_email'] as String,
        userDisplayName: j['user_display_name'] as String,
      );
}

class ApiToken {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;

  const ApiToken({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
  });

  factory ApiToken.fromJson(Map<String, dynamic> j) => ApiToken(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        lastUsedAt: j['last_used_at'] != null ? DateTime.parse(j['last_used_at'] as String) : null,
        expiresAt: j['expires_at'] != null ? DateTime.parse(j['expires_at'] as String) : null,
      );
}

// ---------------------------------------------------------------------------
// Project
// ---------------------------------------------------------------------------

class Project {
  final String id;
  final String name;
  final String color;
  final int position;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String,
        color: j['color'] as String? ?? '#3b82f6',
        position: j['position'] as int? ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Fix task response
// ---------------------------------------------------------------------------

class FixTaskResponse {
  final String taskId;
  final String repoUrl;

  const FixTaskResponse({required this.taskId, required this.repoUrl});

  factory FixTaskResponse.fromJson(Map<String, dynamic> j) => FixTaskResponse(
        taskId: j['task_id'] as String,
        repoUrl: j['repo_url'] as String,
      );
}

// ---------------------------------------------------------------------------
// WebSocket frame
// ---------------------------------------------------------------------------

class WsFrame {
  final String type;
  final dynamic data;

  const WsFrame({required this.type, required this.data});

  factory WsFrame.fromJson(Map<String, dynamic> j) => WsFrame(
        type: j['type'] as String,
        data: j['data'],
      );

  String? get dataAsString => data as String?;
  int? get dataAsInt => data is int ? data as int : null;
}
