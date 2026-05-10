using Windows.Media.SpeechRecognition;

namespace BaumAgent.Services;

/// <summary>
/// Wraps Windows.Media.SpeechRecognition for tap-to-talk dictation.
/// Requires "Microphone" capability in the app manifest when packaged;
/// for unpackaged apps, the OS prompts for mic permission on first use.
/// </summary>
public class VoiceService : IDisposable
{
    private SpeechRecognizer? _recognizer;
    private bool _listening;

    public event Action<string>? PartialResultReceived;
    public event Action<string>? FinalResultReceived;
    public event Action<string>? ErrorOccurred;

    public bool IsListening => _listening;

    /// <summary>Show the system speech UI and return the recognised text, or null if cancelled/failed.</summary>
    public async Task<string?> DictateAsync()
    {
        try
        {
            _recognizer?.Dispose();
            _recognizer = new SpeechRecognizer();

            var dictationConstraint = new SpeechRecognitionTopicConstraint(
                SpeechRecognitionScenario.Dictation, "dictation");
            _recognizer.Constraints.Add(dictationConstraint);
            await _recognizer.CompileConstraintsAsync();

            _recognizer.HypothesisGenerated += (_, e) =>
                PartialResultReceived?.Invoke(e.Hypothesis.Text);

            _listening = true;
            var session = await _recognizer.RecognizeWithUIAsync();
            _listening = false;

            if (session.Status == SpeechRecognitionResultStatus.Success)
            {
                FinalResultReceived?.Invoke(session.Text);
                return session.Text;
            }
            if (session.Status != SpeechRecognitionResultStatus.UserCanceled)
                ErrorOccurred?.Invoke($"Speech recognition failed: {session.Status}");
            return null;
        }
        catch (Exception ex)
        {
            _listening = false;
            // Common COM/WinRT error codes for speech failures
            var hr = (uint)ex.HResult;
            var friendly = hr switch
            {
                0x80045509 => "Microphone not found. Check that a microphone is connected and allowed.",
                0x80131509 or 0x8004503A => "Windows Speech Recognition is not set up. " +
                    "Go to Settings → Time & Language → Speech and enable Online speech recognition.",
                _ => "Speech recognition is unavailable. Enable it in Settings → Privacy & Security → Speech, " +
                     "then ensure microphone access is granted to this app.",
            };
            throw new InvalidOperationException(friendly, ex);
        }
    }

    public async Task StartAsync()
    {
        await DictateAsync();
    }

    public void Stop()
    {
        if (!_listening) return;
        _recognizer?.StopRecognitionAsync().AsTask().GetAwaiter().GetResult();
        _listening = false;
    }

    public void Dispose()
    {
        _recognizer?.Dispose();
        _recognizer = null;
    }
}
