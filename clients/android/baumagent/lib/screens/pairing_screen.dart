import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import 'shell_screen.dart';

// mobile_scanner has no Linux desktop camera backend — desktop users pair by
// pasting the code/URL shown in the web UI instead (that path already works
// unconditionally below; this only gates the camera scanner button/view).
bool get _scannerSupported => !Platform.isLinux;

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _urlCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(text: Platform.isLinux ? 'Linux Device' : 'Android Device');
  bool _urlVerified = false;
  bool _loading = false;
  String? _error;
  bool _showScanner = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiServiceProvider).checkHealth(url);
      setState(() { _urlVerified = true; });
    } catch (e) {
      setState(() { _error = 'Cannot reach server: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _pair() async {
    final url = _urlCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty) { setState(() { _error = 'Enter the pairing code.'; }); return; }

    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ref.read(apiServiceProvider).completePairing(url, code, name);
      await ref.read(storageServiceProvider).saveCredentials(
        url: url,
        token: resp.token,
        email: resp.userEmail,
        displayName: resp.userDisplayName,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ShellScreen()),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _onQrDetected(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue ?? '';
    if (raw.startsWith('baumagent://pair')) {
      final uri = Uri.tryParse(raw);
      if (uri != null) {
        final url = uri.queryParameters['url'];
        final code = uri.queryParameters['code'];
        if (url != null) _urlCtrl.text = url;
        if (code != null) _codeCtrl.text = code;
        setState(() { _showScanner = false; _urlVerified = true; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: _showScanner && _scannerSupported
            ? Stack(children: [
                MobileScanner(onDetect: _onQrDetected),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filled(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() { _showScanner = false; }),
                  ),
                ),
              ])
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Text('BaumAgent', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Connect to your server', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 32),

                    // Step 1: server URL
                    _Card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Server URL', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _urlCtrl,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(hintText: 'https://baum.example.com'),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _loading ? null : _checkUrl,
                              child: const Text('Check connection'),
                            ),
                          ),
                          if (_scannerSupported) ...[
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              icon: const Icon(Icons.qr_code_scanner),
                              tooltip: 'Scan QR',
                              onPressed: () => setState(() { _showScanner = true; }),
                            ),
                          ],
                        ]),
                        if (_urlVerified)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(children: [
                              Icon(Icons.check_circle, color: cs.primary, size: 16),
                              const SizedBox(width: 4),
                              const Text('Connected', style: TextStyle(fontWeight: FontWeight.w500)),
                            ]),
                          ),
                      ],
                    )),
                    const SizedBox(height: 16),

                    // Step 2: pairing code
                    Opacity(
                      opacity: _urlVerified ? 1.0 : 0.4,
                      child: _Card(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Pairing code', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Generate a code in the BaumAgent web portal under Settings → Pair Device.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _codeCtrl,
                            enabled: _urlVerified,
                            decoration: const InputDecoration(hintText: 'Pairing code'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameCtrl,
                            enabled: _urlVerified,
                            decoration: const InputDecoration(hintText: 'Device name'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: (_urlVerified && !_loading) ? _pair : null,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Pair device'),
                          ),
                        ],
                      )),
                    ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: cs.error)),
                      ),
                  ],
                ),
              ),
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
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
