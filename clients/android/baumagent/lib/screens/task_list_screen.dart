import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final queueAsync = ref.watch(queueProvider);
    final notifier = ref.read(taskListProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Queue status bar
          queueAsync.when(
            data: (q) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cs.surfaceContainerHighest,
              child: Row(children: [
                _Badge('Queued ${q.queued.length}', cs.onSurfaceVariant),
                const SizedBox(width: 12),
                _Badge('Running ${q.running.length}', cs.primary),
              ]),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Task list
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (resp) => resp.items.isEmpty
                  ? Center(
                      child: Text('No tasks yet', style: TextStyle(color: cs.onSurfaceVariant)),
                    )
                  : RefreshIndicator(
                      onRefresh: notifier.refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: resp.items.length,
                        itemBuilder: (ctx, i) => _TaskCard(
                          task: resp.items[i],
                          onTap: () => Navigator.of(ctx).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(taskId: resp.items[i].id),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // Pagination
          tasksAsync.whenData((resp) {
            final totalPages = (resp.total / 25).ceil().clamp(1, 999);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cs.surfaceContainerHighest,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: notifier.page > 1 ? () => notifier.prevPage() : null,
                  ),
                  Text('Page ${notifier.page} of $totalPages',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: notifier.page < totalPages
                        ? () => notifier.nextPage(resp.total)
                        : null,
                  ),
                ],
              ),
            );
          }).value ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final BaumTask task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${task.taskType} · ${DateFormat('MMM d, HH:mm').format(task.createdAt.toLocal())}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(task.status),
          ]),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 12, color: color));
  }
}
