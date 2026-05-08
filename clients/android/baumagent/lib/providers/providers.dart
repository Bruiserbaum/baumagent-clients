import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../services/voice_service.dart';

// ── Core services ─────────────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>((_) => StorageService());

final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(ref.watch(storageServiceProvider)),
);

final wsServiceProvider = Provider<WebSocketService>((_) => WebSocketService());

final voiceServiceProvider = Provider<VoiceService>((_) => VoiceService());

// ── Auth state ────────────────────────────────────────────────────────────

final authStateProvider = FutureProvider<bool>((ref) async {
  return ref.watch(storageServiceProvider).hasCredentials();
});

// ── Task list ─────────────────────────────────────────────────────────────

class TaskListNotifier extends StateNotifier<AsyncValue<TaskListResponse>> {
  final ApiService _api;
  int _page = 1;
  static const _pageSize = 25;

  TaskListNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  int get page => _page;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final resp = await _api.listTasks(page: _page, pageSize: _pageSize);
      state = AsyncValue.data(resp);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> nextPage(int total) async {
    if (_page * _pageSize < total) {
      _page++;
      await load();
    }
  }

  Future<void> prevPage() async {
    if (_page > 1) {
      _page--;
      await load();
    }
  }

  Future<void> refresh() => load();
}

final taskListProvider =
    StateNotifierProvider<TaskListNotifier, AsyncValue<TaskListResponse>>(
  (ref) => TaskListNotifier(ref.watch(apiServiceProvider)),
);

// ── Queue status ──────────────────────────────────────────────────────────

final queueProvider = FutureProvider<QueueStatus>((ref) async {
  return ref.watch(apiServiceProvider).getQueue();
});

// ── Task detail ───────────────────────────────────────────────────────────

final taskDetailProvider = FutureProvider.family<BaumTask, String>((ref, taskId) async {
  return ref.watch(apiServiceProvider).getTask(taskId);
});

// ── Token list ────────────────────────────────────────────────────────────

final tokenListProvider = FutureProvider<List<ApiToken>>((ref) async {
  return ref.watch(apiServiceProvider).listTokens();
});

// ── Exports ───────────────────────────────────────────────────────────────

final exportsProvider = FutureProvider.family<List<ExportFile>, String>((ref, taskId) async {
  return ref.watch(apiServiceProvider).listExports(taskId);
});
