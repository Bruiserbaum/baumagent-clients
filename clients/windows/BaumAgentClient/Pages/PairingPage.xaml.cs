using BaumAgent.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace BaumAgent.Pages;

public sealed partial class PairingPage : Page
{
    private string? _verifiedUrl;
    private readonly BaumAgentApiClient _api = App.GetService<BaumAgentApiClient>();
    private readonly CredentialService _creds = App.GetService<CredentialService>();

    public PairingPage() => InitializeComponent();

    private async void CheckUrl_Click(object sender, RoutedEventArgs e)
    {
        var url = UrlBox.Text.Trim().TrimEnd('/');
        if (string.IsNullOrWhiteSpace(url)) return;

        Spinner.IsActive = true;
        CheckUrlButton.IsEnabled = false;
        UrlStatus.Text = "Checking…";

        try
        {
            await _api.GetHealthAsync(url);
            _verifiedUrl = url;
            UrlStatus.Text = "Connected.";
            UrlStatus.Foreground = App.Current.Resources["BaumSuccessBrush"] as Microsoft.UI.Xaml.Media.Brush;
            PairStep.Opacity = 1.0;
            PairButton.IsEnabled = true;
        }
        catch (Exception ex)
        {
            UrlStatus.Text = $"Cannot reach BaumAgent: {ex.Message}";
            UrlStatus.Foreground = App.Current.Resources["BaumDangerBrush"] as Microsoft.UI.Xaml.Media.Brush;
        }
        finally
        {
            Spinner.IsActive = false;
            CheckUrlButton.IsEnabled = true;
        }
    }

    private async void Pair_Click(object sender, RoutedEventArgs e)
    {
        if (_verifiedUrl is null) return;
        var code = CodeBox.Text.Trim();
        var deviceName = DeviceNameBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(code)) return;

        Spinner.IsActive = true;
        PairButton.IsEnabled = false;
        PairStatus.Text = "Pairing…";

        try
        {
            var result = await _api.CompletePairingAsync(_verifiedUrl, code, deviceName);
            _creds.Save(_verifiedUrl, result.Token, result.UserEmail, result.UserDisplayName);
            _api.Reconfigure();

            // Register for push notifications (non-fatal if it fails)
            try { await App.GetService<PushService>().RegisterAsync(deviceName); } catch { }

            Frame.Navigate(typeof(ShellPage));
        }
        catch (Exception ex)
        {
            PairStatus.Text = $"Pairing failed: {ex.Message}";
            PairStatus.Foreground = App.Current.Resources["BaumDangerBrush"] as Microsoft.UI.Xaml.Media.Brush;
            PairButton.IsEnabled = true;
        }
        finally
        {
            Spinner.IsActive = false;
        }
    }
}
