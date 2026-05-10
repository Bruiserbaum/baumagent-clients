using Microsoft.UI.Dispatching;

namespace BaumAgent;

internal static class DispatcherExtensions
{
    internal static Task EnqueueAsync(this DispatcherQueue q, Action action)
    {
        var tcs = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        if (!q.TryEnqueue(() => { action(); tcs.SetResult(); }))
            tcs.SetException(new InvalidOperationException("DispatcherQueue is not available."));
        return tcs.Task;
    }

    internal static Task EnqueueAsync(this DispatcherQueue q, Func<Task> asyncAction)
    {
        var tcs = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        if (!q.TryEnqueue(async () =>
        {
            try { await asyncAction(); tcs.SetResult(); }
            catch (Exception ex) { tcs.SetException(ex); }
        }))
            tcs.SetException(new InvalidOperationException("DispatcherQueue is not available."));
        return tcs.Task;
    }
}
