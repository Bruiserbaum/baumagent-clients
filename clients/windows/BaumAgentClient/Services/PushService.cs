using Microsoft.Windows.AppNotifications;
using Microsoft.Windows.AppNotifications.Builder;

namespace BaumAgent.Services;

/// <summary>
/// Handles local toast notifications and stubs WNS push registration.
///
/// WNS channel registration requires package identity (MSIX packaging).
/// When running as an unpackaged app, WNS is unavailable. Local notifications
/// via AppNotificationManager work in both packaged and unpackaged contexts.
///
/// To enable real WNS push: package the app with MSIX and uncomment the
/// WNS registration code in RegisterAsync().
/// </summary>
public class PushService
{
    private readonly BaumAgentApiClient _api;

    public PushService(BaumAgentApiClient api) => _api = api;

    public void Initialize()
    {
        try
        {
            AppNotificationManager.Default.Register();
            AppNotificationManager.Default.NotificationInvoked += OnNotificationInvoked;
        }
        catch
        {
            // Notification registration can fail in some contexts; not fatal.
        }
    }

    /// <summary>
    /// Attempt WNS channel registration and send token to server.
    /// Currently stubs WNS (requires packaging); local notifications always work.
    /// </summary>
    public async Task RegisterAsync(string deviceLabel = "Windows PC")
    {
        // TODO: When app is packaged with MSIX, replace stub with:
        // var channel = await PushNotificationChannelManager
        //     .CreatePushNotificationChannelForApplicationAsync();
        // await _api.RegisterPushTokenAsync("wns", channel.Uri.ToString(), deviceLabel);
        await Task.CompletedTask;
    }

    /// <summary>Show a local toast (works without packaging or WNS).</summary>
    public void ShowLocalNotification(string title, string body, string? taskId = null)
    {
        try
        {
            var builder = new AppNotificationBuilder()
                .AddText(title)
                .AddText(body);

            if (taskId is not null)
                builder.AddArgument("taskId", taskId);

            AppNotificationManager.Default.Show(builder.BuildNotification());
        }
        catch { /* Never crash the app on notification failure */ }
    }

    private static void OnNotificationInvoked(
        AppNotificationManager sender,
        AppNotificationActivatedEventArgs args)
    {
        if (args.Arguments.TryGetValue("taskId", out var taskId))
        {
            // Navigate to the task detail page
            App.MainWindow?.DispatcherQueue.TryEnqueue(() =>
            {
                App.MainWindow.AppWindow.Show();
                // Navigation handled by ShellPage listening to this event
                TaskNotificationActivated?.Invoke(taskId);
            });
        }
    }

    public static event Action<string>? TaskNotificationActivated;
}
