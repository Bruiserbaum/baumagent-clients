using BaumAgent.Models;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading.Channels;

namespace BaumAgent.Services;

public class WebSocketService
{
    private readonly CredentialService _creds;

    public WebSocketService(CredentialService creds) => _creds = creds;

    public async IAsyncEnumerable<WsFrame> StreamAsync(
        string taskId,
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct = default)
    {
        var channel = Channel.CreateUnbounded<WsFrame>();
        _ = FeedChannelAsync(taskId, channel.Writer, ct);

        await foreach (var frame in channel.Reader.ReadAllAsync(ct))
            yield return frame;
    }

    private async Task FeedChannelAsync(string taskId, ChannelWriter<WsFrame> writer, CancellationToken ct)
    {
        try
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
                    delay = TimeSpan.FromSeconds(1);

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
                        writer.TryWrite(frame);

                        if (frame.Type is "done" or "error")
                        {
                            done = true;
                            break;
                        }
                    }
                }
                catch (OperationCanceledException) { return; }
                catch { /* connection error — fall through to reconnect */ }

                closed:
                if (done || ct.IsCancellationRequested) return;

                try { await Task.Delay(delay, ct); }
                catch (OperationCanceledException) { return; }

                delay = TimeSpan.FromSeconds(Math.Min(delay.TotalSeconds * 2, MaxDelaySeconds));
            }
        }
        finally
        {
            writer.Complete();
        }
    }
}
