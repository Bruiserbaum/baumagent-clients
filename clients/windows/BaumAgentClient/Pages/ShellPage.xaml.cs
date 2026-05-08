using BaumAgent.Services;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;

namespace BaumAgent.Pages;

public sealed partial class ShellPage : Page
{
    private readonly CredentialService _creds = App.GetService<CredentialService>();
    private readonly PushService _push = App.GetService<PushService>();

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
            "TaskList" => ContentFrame.Navigate(typeof(TaskListPage)),
            "TaskCreate" => ContentFrame.Navigate(typeof(TaskCreatePage)),
            "Settings" => ContentFrame.Navigate(typeof(SettingsPage)),
            _ => false,
        };
    }

    private void NavView_BackRequested(NavigationView sender, NavigationViewBackRequestedEventArgs args)
    {
        if (ContentFrame.CanGoBack) ContentFrame.GoBack();
    }
}
