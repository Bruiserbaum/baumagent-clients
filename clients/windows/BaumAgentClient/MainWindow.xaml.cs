using BaumAgent.Pages;
using BaumAgent.Services;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Windows.Graphics;

namespace BaumAgent;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        SetupWindow();
        NavigateToStartPage();
    }

    private void SetupWindow()
    {
        var appWindow = AppWindow;
        appWindow.SetIcon("Assets/baumagent.ico");
        appWindow.Resize(new SizeInt32(1100, 720));
        appWindow.Title = "BaumAgent";

        // Dark title bar
        if (AppWindowTitleBar.IsCustomizationSupported())
        {
            var titleBar = appWindow.TitleBar;
            titleBar.ExtendsContentIntoTitleBar = false;
            titleBar.ButtonBackgroundColor = Colors.Transparent;
            titleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
        }

        // Set dark theme
        if (Content is FrameworkElement fe)
            fe.RequestedTheme = ElementTheme.Dark;
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
        Application.Current.Exit();
    }
}
