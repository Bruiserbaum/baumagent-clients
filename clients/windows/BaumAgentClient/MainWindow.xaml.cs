using BaumAgent.Pages;
using BaumAgent.Services;
using H.NotifyIcon;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Graphics;

namespace BaumAgent;

public sealed partial class MainWindow : Window
{
    private TaskbarIcon? _trayIcon;

    public MainWindow()
    {
        InitializeComponent();
        SetupWindow();
        SetupTrayIcon();
        NavigateToStartPage();
    }

    private void SetupWindow()
    {
        var appWindow = AppWindow;
        appWindow.Resize(new SizeInt32(1100, 720));
        appWindow.Title = "BaumAgent";

        if (AppWindowTitleBar.IsCustomizationSupported())
        {
            var titleBar = appWindow.TitleBar;
            titleBar.ExtendsContentIntoTitleBar = false;
            titleBar.ButtonBackgroundColor = Colors.Transparent;
            titleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
        }

        if (Content is FrameworkElement fe)
            fe.RequestedTheme = ElementTheme.Dark;
    }

    private void SetupTrayIcon()
    {
        var openItem = new MenuFlyoutItem { Text = "Open" };
        openItem.Click += TrayOpen_Click;

        var quitItem = new MenuFlyoutItem { Text = "Quit" };
        quitItem.Click += TrayQuit_Click;

        var flyout = new MenuFlyout();
        flyout.Items.Add(openItem);
        flyout.Items.Add(new MenuFlyoutSeparator());
        flyout.Items.Add(quitItem);

        _trayIcon = new TaskbarIcon
        {
            ToolTipText = "BaumAgent",
            ContextFlyout = flyout,
        };
    }

    private void NavigateToStartPage()
    {
        var creds = App.GetService<CredentialService>();
        if (creds.HasCredentials())
            RootFrame.Navigate(typeof(ShellPage));
        else
            RootFrame.Navigate(typeof(PairingPage));
    }

    private void TrayOpen_Click(object sender, RoutedEventArgs e)
    {
        AppWindow.Show();
        AppWindow.MoveInZOrderAtTop();
    }

    private void TrayQuit_Click(object sender, RoutedEventArgs e)
    {
        _trayIcon?.Dispose();
        Application.Current.Exit();
    }
}
