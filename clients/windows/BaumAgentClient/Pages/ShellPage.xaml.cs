using BaumAgent.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;

namespace BaumAgent.Pages;

public sealed partial class ShellPage : Page
{
    private readonly CredentialService _creds = App.GetService<CredentialService>();
    private readonly PushService _push = App.GetService<PushService>();
    private readonly UpdateService _updater = new();
    private UpdateInfo? _pendingUpdate;

    public ShellPage()
    {
        InitializeComponent();
        UserDisplay.Text = _creds.GetUserDisplayName() ?? "BaumAgent";
        UserEmail.Text = _creds.GetUserEmail() ?? "";

        _push.Initialize();
        PushService.TaskNotificationActivated += taskId =>
            ContentFrame.Navigate(typeof(TaskDetailPage), taskId);

        ContentFrame.Navigate(typeof(TaskListPage));
        NavView.SelectedItem = NavView.MenuItems[0];

        _ = CheckForUpdateAsync();
    }

    private async Task CheckForUpdateAsync()
    {
        var update = await _updater.CheckForUpdateAsync();
        if (update is null) return;
        _pendingUpdate = update;
        UpdateBannerText.Text = $"Update available: v{update.Version}";
        UpdateBanner.Visibility = Visibility.Visible;
    }

    private async void UpdateDownload_Click(object sender, RoutedEventArgs e)
    {
        if (_pendingUpdate is null) return;
        UpdateDownloadBtn.IsEnabled = false;
        UpdateBannerText.Text = "Downloading…";

        await _updater.DownloadAndInstallAsync(_pendingUpdate, new Progress<int>(pct =>
        {
            UpdateBannerText.Text = $"Downloading… {pct}%";
        }));
    }

    private void UpdateDismiss_Click(object sender, RoutedEventArgs e)
    {
        UpdateBanner.Visibility = Visibility.Collapsed;
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.IsSettingsSelected)
        {
            ContentFrame.Navigate(typeof(SettingsPage));
            return;
        }
        var tag = (args.SelectedItem as NavigationViewItem)?.Tag?.ToString();
        _ = tag switch
        {
            "TaskList"   => ContentFrame.Navigate(typeof(TaskListPage)),
            "TaskCreate" => ContentFrame.Navigate(typeof(TaskCreatePage)),
            "History"    => ContentFrame.Navigate(typeof(HistoryPage)),
            _            => false,
        };
    }

    private void NavView_BackRequested(NavigationView sender, NavigationViewBackRequestedEventArgs args)
    {
        if (ContentFrame.CanGoBack) ContentFrame.GoBack();
    }
}
