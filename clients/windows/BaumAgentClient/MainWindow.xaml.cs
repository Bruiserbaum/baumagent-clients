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
        try
        {
            InitializeComponent();
            SetupWindow();
            NavigateToStartPage();
        }
        catch (Exception ex)
        {
            App.Log("MainWindow.ctor", ex);
            throw;
        }
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

            var bg      = Windows.UI.Color.FromArgb(255, 15,  23,  42);   // #0f172a
            var surface = Windows.UI.Color.FromArgb(255, 22,  33,  62);   // #16213e
            var text    = Windows.UI.Color.FromArgb(255, 226, 232, 240);  // #e2e8f0
            var sub     = Windows.UI.Color.FromArgb(255, 100, 116, 139);  // #64748b
            var accent  = Windows.UI.Color.FromArgb(255, 59,  130, 246);  // #3b82f6

            titleBar.BackgroundColor               = bg;
            titleBar.InactiveBackgroundColor       = bg;
            titleBar.ForegroundColor               = text;
            titleBar.InactiveForegroundColor       = sub;
            titleBar.ButtonBackgroundColor         = bg;
            titleBar.ButtonInactiveBackgroundColor = bg;
            titleBar.ButtonForegroundColor         = text;
            titleBar.ButtonInactiveForegroundColor = sub;
            titleBar.ButtonHoverBackgroundColor    = surface;
            titleBar.ButtonHoverForegroundColor    = text;
            titleBar.ButtonPressedBackgroundColor  = accent;
            titleBar.ButtonPressedForegroundColor  = Windows.UI.Color.FromArgb(255, 255, 255, 255);
        }

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
}
