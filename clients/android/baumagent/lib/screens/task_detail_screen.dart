import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  BaumTask? _task;
  String _log = '';
  String _liveStatus = '';
  int? _progress;
  List<ExportFile> _exports = [];
  StreamSubscription? _wsSub;
  final _scrollCtrl = ScrollController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final task = await ref.read(apiServiceProvider).getTask(widget.taskId);
      setState(() {
        _task = task;
        _liveStatus = task.status;
        _log = task.log ?? '';
        _loading = false;
      });
      if (task.isTerminal) {
        await _loadExports();
      } else {
        _startStream();
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _startStream() {
    final ws = ref.read(wsServiceProvider);
    final storage = ref.read(storageServiceProvider);

    _wsSub?.cancel();

    Future(() async {
      final url = await storage.getUrl() ?? '';
      final token = await storage.getToken() ?? '';

      _wsSub = ws.stream(url, widget.taskId, token).listen(
        (frame) {
          if (!mounted) return;
          setState(() {
            switch (frame.type) {
              case 'log':
                _log += frame.dataAsString ?? '';
              case 'status':
                _liveStatus = frame.dataAsString ?? _liveStatus;
              case 'progress':
                _progress = frame.dataAsInt;
              case 'done':
                final data = frame.data as Map<String, dynamic>?;
                _liveStatus = (data?['status'] as String?) ?? _liveStatus;
                _progress = null;
                if (_liveStatus == 'complete') {
                  _loadExports();
                }
            }
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
            }
          });
        },
      );
    });
  }

  Future<void> _loadExports() async {
    try {
      final exports = await ref.read(apiServiceProvider).listExports(widget.taskId);
      if (mounted) setState(() => _exports = exports);
    } catch (_) {}
  }

  Future<void> _cancel() async {
    try {
      await ref.read(apiServiceProvider).cancelTask(widget.taskId);
      setState(() => _liveStatus = 'cancelled');
    } catch (e) {
      _showError('Cancel failed', e.toString());
    }
  }

  Future<void> _retry() async {
    try {
      final task = await ref.read(apiServiceProvider).retryTask(widget.taskId);
      setState(() {
        _task = task;
        _liveStatus = task.status;
        _log = '';
        _progress = null;
        _exports = [];
      });
      _startStream();
    } catch (e) {
      _showError('Retry failed', e.toString());
    }
  }

  void _showError(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final task = _task;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Task Detail'),
        actions: [
          if (task != null && !task.isTerminal)
            TextButton(onPressed: _cancel, child: Text('Cancel', style: TextStyle(color: cs.error))),
          if (task != null && task.isTerminal)
            TextButton(onPressed: _retry, child: const Text('Re-run')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(children: [
                  // Header
                  _buildHeader(cs, task),

                  // Progress
                  if (_progress != null)
                    LinearProgressIndicator(value: _progress! / 100),

                  // PR link
                  if (task?.prUrl != null)
                    ListTile(
                      leading: const Icon(Icons.merge_type),
                      title: Text('PR #${task!.prNumber}'),
                      trailing: const Icon(Icons.open_in_new, size: 16),
                      onTap: () => launchUrl(Uri.parse(task.prUrl!)),
                    ),

                  // Log
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0f172a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _log.isEmpty ? 'Connecting…' : _log,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFFa3e635),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),

                  // Exports
                  if (_exports.isNotEmpty) _buildExports(cs),
                ]),
    );
  }

  Widget _buildHeader(ColorScheme cs, BaumTask? task) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task?.description ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Row(children: [
                _StatusChip(_liveStatus),
                const SizedBox(width: 8),
                Text(task?.taskType ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                Text(task?.llmModel ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExports(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exports', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._exports.map(
            (e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.filename, style: const TextStyle(fontSize: 13)),
              subtitle: Text(e.sizeDisplay, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              trailing: TextButton(
                onPressed: () => launchUrl(Uri.parse(e.downloadUrl)),
                child: const Text('Download'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'complete' => const Color(0xFF4ade80),
      'failed' => const Color(0xFFf87171),
      'cancelled' => const Color(0xFFfbbf24),
      'running' => const Color(0xFF60a5fa),
      _ => const Color(0xFF94a3b8),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
