import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'task_detail_screen.dart';

class TaskCreateScreen extends ConsumerStatefulWidget {
  const TaskCreateScreen({super.key});

  @override
  ConsumerState<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends ConsumerState<TaskCreateScreen> {
  final _descCtrl = TextEditingController();
  final _repoCtrl = TextEditingController();
  final _branchCtrl = TextEditingController(text: 'main');
  String _taskType = 'research';
  String _model = 'claude-opus-4-6';
  bool _loading = false;
  bool _listening = false;
  String? _error;

  static const _taskTypes = [
    ('research', 'Research'),
    ('deep_research', 'Deep Research'),
    ('code', 'Code (GitHub)'),
    ('structured_document', 'Structured Document'),
  ];

  static const _models = [
    'claude-opus-4-6',
    'claude-sonnet-4-6',
    'claude-haiku-4-5-20251001',
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _repoCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _dictate() async {
    final voice = ref.read(voiceServiceProvider);
    setState(() { _listening = true; _error = null; });
    try {
      final text = await voice.dictate();
      if (text != null) {
        _descCtrl.text += text;
      }
    } catch (e) {
      setState(() { _error = 'Voice error: $e'; });
    } finally {
      setState(() { _listening = false; });
    }
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) { setState(() { _error = 'Description is required.'; }); return; }
    if (_taskType == 'code' && _repoCtrl.text.trim().isEmpty) {
      setState(() { _error = 'Repository URL is required for code tasks.'; }); return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final task = await ref.read(apiServiceProvider).createTask(
        description: desc,
        taskType: _taskType,
        llmModel: _model,
        repoUrl: _taskType == 'code' ? _repoCtrl.text.trim() : '',
        baseBranch: _taskType == 'code' ? _branchCtrl.text.trim() : 'main',
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
        );
        _descCtrl.clear();
      }
    } catch (e) {
      setState(() { _error = 'Failed to create task: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Create Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Description
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Describe the task…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    OutlinedButton.icon(
                      icon: Icon(_listening ? Icons.stop : Icons.mic),
                      label: Text(_listening ? 'Listening…' : 'Dictate'),
                      onPressed: _listening ? null : _dictate,
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Task type + model
            _SectionCard(
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Task type', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _taskType,
                        items: _taskTypes
                            .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                            .toList(),
                        onChanged: (v) => setState(() => _taskType = v!),
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Model', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _model,
                        items: _models
                            .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (v) => setState(() => _model = v!),
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Code options
            if (_taskType == 'code')
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Repository', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _repoCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'https://github.com/…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _branchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Base branch (default: main)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

            if (_taskType == 'code') const SizedBox(height: 12),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),

            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create task →'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}
