using BaumAgent.Models;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;

namespace BaumAgent.Services;

/// <summary>
/// Connects to /ws/tasks/{taskId}/logs and yields typed frames.
/// Automatically reconnects with exponential backoff until a "done" frame arrives
/// or the CancellationToken is cancelled.
/// </summary>
public class WebSocketService
{
    private readonly CredentialService _creds;

    public WebSocketService(CredentialService creds) => _creds = creds;

    public async IAsyncEnumerable<WsFrame> StreamAsync(
        string taskId,
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct = default)
    {
        var (url, token) = _creds.GetCredentials();
        var wsBase = url.Replace("https://", "wss://").Replace("http://", "ws://").TrimEnd('/');
        var wsUrl = $"{wsBase}/ws/tasks/{taskId}/logs?token={token}";

        var delay = TimeSpan.FromSeconds(1);
        const int MaxDelaySeconds = 30;

        while (!ct.IsCancellationRequested)
        {
            using var ws = new ClientWebSocket();
            bool done = false;

            try
            {
                await ws.ConnectAsync(new Uri(wsUrl), ct);
                delay = TimeSpan.FromSeconds(1); // reset backoff on success

                var buf = new byte[32 * 1024];

                while (!ct.IsCancellationRequested)
                {
                    var sb = new StringBuilder();
                    WebSocketReceiveResult result;

                    do
                    {
                        result = await ws.ReceiveAsync(buf, ct);
                        if (result.MessageType == WebSocketMessageType.Close) goto closed;
                        sb.Append(Encoding.UTF8.GetString(buf, 0, result.Count));
                    }
                    while (!result.EndOfMessage);

                    WsFrame? frame;
                    try { frame = JsonSerializer.Deserialize<WsFrame>(sb.ToString()); }
                    catch { continue; }

                    if (frame is null) continue;
                    yield return frame;

                    if (frame.Type is "done" or "error")
                    {
                        done = true;
                        break;
                    }
                }
            }
            catch (OperationCanceledException) { yield break; }
            catch { /* connection error — fall through to reconnect */ }

            closed:
            if (done || ct.IsCancellationRequested) yield break;

            try { await Task.Delay(delay, ct); }
            catch (OperationCanceledException) { yield break; }

            delay = TimeSpan.FromSeconds(Math.Min(delay.TotalSeconds * 2, MaxDelaySeconds));
        }
    }
}
