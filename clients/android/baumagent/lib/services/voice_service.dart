import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  final _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(onError: (_) {});
    return _initialized;
  }

  bool get isListening => _speech.isListening;

  /// Returns the recognised text, or null if unavailable / cancelled.
  Future<String?> dictate() async {
    if (!await _ensureInitialized()) return null;

    final completer = Completer<String?>();

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          completer.complete(result.recognizedWords.isEmpty ? null : result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );

    return completer.future;
  }

  void stop() => _speech.stop();
}
