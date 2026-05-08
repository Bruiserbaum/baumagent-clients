import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'pairing_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _display = '';
  String _email = '';
  String _url = '';
  List<ApiToken>? _tokens;
  String? _tokensError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTokens();
  }

  Future<void> _loadProfile() async {
    final creds = await ref.read(storageServiceProvider).getCredentials();
    if (mounted) setState(() { _display = creds.display; _email = creds.email; _url = creds.url; });
  }

  Future<void> _loadTokens() async {
    try {
      final tokens = await ref.read(apiServiceProvider).listTokens();
      if (mounted) setState(() { _tokens = tokens; _tokensError = null; });
    } catch (e) {
      if (mounted) setState(() { _tokensError = e.toString(); });
    }
  }

  Future<void> _revokeToken(String tokenId) async {
    try {
      await ref.read(apiServiceProvider).revokeToken(tokenId);
      await _loadTokens();
    } catch (e) {
      if (mounted) setState(() { _tokensError = 'Revoke failed: $e'; });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('This will remove your credentials. You will need to re-pair to use the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final tokens = await ref.read(apiServiceProvider).listTokens();
      for (final t in tokens) {
        await ref.read(apiServiceProvider).revokeToken(t.id);
      }
    } catch (_) {}

    await ref.read(storageServiceProvider).clearCredentials();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PairingScreen()),
        (_) => false,
      );
    }
  }

  void _rePair() {
    ref.read(storageServiceProvider).clearCredentials();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PairingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _InfoRow('User', _display),
                _InfoRow('Email', _email),
                _InfoRow('Server', _url),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tokens
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(child: Text('API Tokens', style: TextStyle(fontWeight: FontWeight.w600))),
                  TextButton(onPressed: _loadTokens, child: const Text('Refresh')),
                ]),
                if (_tokensError != null)
                  Text(_tokensError!, style: TextStyle(color: cs.error, fontSize: 12)),
                if (_tokens == null && _tokensError == null)
                  const Center(child: CircularProgressIndicator()),
                if (_tokens != null)
                  ..._tokens!.map((t) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.name.isEmpty ? 'Token …${t.id.substring(t.id.length - 8)}' : t.name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      t.lastUsedAt != null
                          ? 'Last used ${DateFormat('MMM d').format(t.lastUsedAt!.toLocal())}'
                          : 'Never used',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    trailing: TextButton(
                      onPressed: () => _revokeToken(t.id),
                      child: Text('Revoke', style: TextStyle(color: cs.error)),
                    ),
                  )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Danger zone
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Account', style: TextStyle(fontWeight: FontWeight.w600, color: cs.error)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _rePair, child: const Text('Re-pair device')),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: cs.error),
                  onPressed: _signOut,
                  child: const Text('Sign out & unpair'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // About
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('About', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('BaumAgent Android Client v1.0.0', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                Text('Flutter · Riverpod · firebase_messaging', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 60, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}
