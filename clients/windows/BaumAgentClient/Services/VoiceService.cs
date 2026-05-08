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
