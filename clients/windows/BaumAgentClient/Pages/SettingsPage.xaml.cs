using BaumAgent.Models;
using BaumAgent.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace BaumAgent.Pages;

public sealed partial class SettingsPage : Page
{
    private readonly BaumAgentApiClient _api = App.GetService<BaumAgentApiClient>();
    private readonly CredentialService _creds = App.GetService<CredentialService>();

    public SettingsPage() => InitializeComponent();

    protected override async void OnNavigatedTo(Microsoft.UI.Xaml.Navigation.NavigationEventArgs e)
    {
        var (url, _) = _creds.GetCredentials();
        UserDisplayText.Text = _creds.GetUserDisplayName() ?? "";
        UserEmailText.Text = _creds.GetUserEmail() ?? "";
        ServerUrlText.Text = url;
        await LoadTokensAsync();
    }

    private async Task LoadTokensAsync()
    {
        TokensError.Text = "";
        try
        {
            var tokens = await _api.ListTokensAsync();
            TokensList.ItemsSource = tokens.Select(t => new TokenRow(t)).ToList();
        }
        catch (Exception ex)
        {
            TokensError.Text = $"Could not load tokens: {ex.Message}";
        }
    }

    private async void RefreshTokens_Click(object sender, RoutedEventArgs e)
        => await LoadTokensAsync();

    private async void RevokeToken_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as Button)?.Tag is not string tokenId) return;

        var confirm = new ContentDialog
        {
            Title = "Revoke token",
            Content = "This will permanently delete this API token. Any device using it will be signed out.",
            PrimaryButtonText = "Revoke",
            CloseButtonText = "Cancel",
            XamlRoot = XamlRoot,
        };

        if (await confirm.ShowAsync() != ContentDialogResult.Primary) return;

        try
        {
            await _api.RevokeTokenAsync(tokenId);
            await LoadTokensAsync();
        }
        catch (Exception ex)
        {
            TokensError.Text = $"Revoke failed: {ex.Message}";
        }
    }

    private void RePair_Click(object sender, RoutedEventArgs e)
    {
        _creds.Clear();
        _api.Reconfigure();
        Frame.Navigate(typeof(PairingPage));
    }

    private async void SignOut_Click(object sender, RoutedEventArgs e)
    {
        var confirm = new ContentDialog
        {
            Title = "Sign out",
            Content = "This will remove your credentials from this device. You will need to re-pair to use the app.",
            PrimaryButtonText = "Sign out",
            CloseButtonText = "Cancel",
            XamlRoot = XamlRoot,
        };

        if (await confirm.ShowAsync() != ContentDialogResult.Primary) return;

        try
        {
            // Best-effort: revoke all tokens for this user before clearing local credentials
            var tokens = await _api.ListTokensAsync();
            foreach (var t in tokens)
                await _api.RevokeTokenAsync(t.Id);
        }
        catch { }

        _creds.Clear();
        _api.Reconfigure();
        Frame.Navigate(typeof(PairingPage));
    }
}

internal record TokenRow(ApiToken Token)
{
    public string Id => Token.Id;
    public string Label => string.IsNullOrEmpty(Token.Name)
        ? $"Token …{Token.Id[^Math.Min(8, Token.Id.Length)..]}"
        : Token.Name;
    public string CreatedDisplay => $"Created {Token.CreatedAt.ToLocalTime():MMM d, yyyy}";
    public string LastUsedDisplay => Token.LastUsedAt is null
        ? "Never used"
        : $"Last used {Token.LastUsedAt.Value.ToLocalTime():MMM d}";
}
