import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'task_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Project> _projects = [];
  List<BaumTask> _allFinished = [];
  String? _activeProjectId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.listProjects(),
        api.listTasks(page: 1, pageSize: 200),
      ]);
      final projects = results[0] as List<Project>;
      final taskResp = results[1] as TaskListResponse;
      final finished = taskResp.items.where((t) => t.isTerminal).toList();
      setState(() {
        _projects = projects;
        _allFinished = finished;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<BaumTask> get _filtered {
    if (_activeProjectId == null) return _allFinished;
    return _allFinished.where((t) => t.projectId == _activeProjectId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: TextStyle(color: cs.error)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      // Projects section
                      if (_projects.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text('Projects',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _projects.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final p = _projects[i];
                                final active = _activeProjectId == p.id;
                                final count = _allFinished
                                    .where((t) => t.projectId == p.id)
                                    .length;
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _activeProjectId = active ? null : p.id;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _parseColor(p.color)
                                          .withOpacity(active ? 1.0 : 0.75),
                                      borderRadius: BorderRadius.circular(12),
                                      border: active
                                          ? Border.all(color: Colors.white, width: 2)
                                          : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14)),
                                        Text('$count task${count == 1 ? '' : 's'}',
                                            style: const TextStyle(
                                                color: Color(0xCCffffff), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      ],

                      // Filter badge
                      if (_activeProjectId != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                            child: Row(children: [
                              Text(
                                '— ${_projects.firstWhere((p) => p.id == _activeProjectId).name}',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => setState(() => _activeProjectId = null),
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero),
                                child: const Text('Show all'),
                              ),
                            ]),
                          ),
                        ),

                      // Tasks header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            'Finished Tasks (${_filtered.length})',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ),

                      // Tasks list
                      if (_filtered.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No finished tasks yet.')),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final t = _filtered[i];
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                                child: Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: cs.outlineVariant),
                                  ),
                                  child: ListTile(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => TaskDetailScreen(taskId: t.id)),
                                    ),
                                    leading: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [_StatusDot(t.status)],
                                    ),
                                    title: Text(t.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    subtitle: Row(children: [
                                      _TypeChip(t.taskType),
                                      const SizedBox(width: 6),
                                      Text(
                                        _dateLabel(t.updatedAt),
                                        style: TextStyle(
                                            fontSize: 11, color: cs.onSurfaceVariant),
                                      ),
                                    ]),
                                    trailing: const Icon(Icons.chevron_right, size: 18),
                                  ),
                                ),
                              );
                            },
                            childCount: _filtered.length,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF3b82f6);
    }
  }

  String _dateLabel(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'complete'  => const Color(0xFF4ade80),
      'failed'    => const Color(0xFFf87171),
      'cancelled' => const Color(0xFFfbbf24),
      _           => const Color(0xFF94a3b8),
    };
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String taskType;
  const _TypeChip(this.taskType);

  @override
  Widget build(BuildContext context) {
    final label = switch (taskType) {
      'research'            => 'RESEARCH',
      'deep_research'       => 'DEEP',
      'coding'              => 'SCRIPT',
      'structured_document' => 'DOC',
      'instructions'        => 'INSTRUCTIONS',
      _                     => 'GITHUB',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
