using BaumAgent.Models;
using BaumAgent.Services;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace BaumAgent.Pages;

public sealed partial class SettingsPage : Page
{
    private readonly BaumAgentApiClient _api = App.GetService<BaumAgentApiClient>();
    private readonly CredentialService _creds = App.GetService<CredentialService>();
    private readonly UpdateService _updater = new();
    private UpdateInfo? _pendingUpdate;

    public SettingsPage() => InitializeComponent();

    protected override async void OnNavigatedTo(Microsoft.UI.Xaml.Navigation.NavigationEventArgs e)
    {
        var (url, _) = _creds.GetCredentials();
        UserDisplayText.Text = _creds.GetUserDisplayName() ?? "";
        UserEmailText.Text   = _creds.GetUserEmail() ?? "";
        ServerUrlText.Text   = url;

        var v = UpdateService.CurrentVersion;
        VersionText.Text = $"BaumAgent Windows Client v{v.Major}.{v.Minor}.{v.Build}";

        // Load both sections in parallel; failures are handled independently.
        await Task.WhenAll(LoadTokensAsync(), LoadNexusAsync());
    }

    // ── API Tokens ────────────────────────────────────────────────────────

    private async Task LoadTokensAsync()
    {
        TokensError.Text = "";
        TokensErrorPanel.Visibility = Visibility.Collapsed;
        TokensRePairBtn.Visibility  = Visibility.Collapsed;

        try
        {
            var tokens = await _api.ListTokensAsync();
            TokensList.ItemsSource = tokens.Select(t => new TokenRow(t)).ToList();
        }
        catch (Exception ex)
        {
            TokensError.Text = $"Could not load tokens: {ex.Message}";
            TokensErrorPanel.Visibility = Visibility.Visible;

            // Show the re-pair shortcut when the error looks like an auth issue.
            bool isAuthError = ex.Message.Contains("HTML") ||
                               ex.Message.Contains("session") ||
                               ex.Message.Contains("token") ||
                               ex.Message.Contains("401") ||
                               ex.Message.Contains("403");
            TokensRePairBtn.Visibility = isAuthError
                ? Visibility.Visible
                : Visibility.Collapsed;
        }
    }

    private async void RefreshTokens_Click(object sender, RoutedEventArgs e)
        => await LoadTokensAsync();

    private async void RevokeToken_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as Button)?.Tag is not string tokenId) return;

        var confirm = new ContentDialog
        {
            Title          = "Revoke token",
            Content        = "This will permanently delete this API token. Any device using it will be signed out.",
            PrimaryButtonText = "Revoke",
            CloseButtonText   = "Cancel",
            XamlRoot       = XamlRoot,
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
            TokensErrorPanel.Visibility = Visibility.Visible;
        }
    }

    // ── Git Nexus ─────────────────────────────────────────────────────────

    private async Task LoadNexusAsync()
    {
        NexusStatusText.Text       = "Loading…";
        NexusStatusText.Visibility = Visibility.Visible;
        NexusError.Text            = "";
        NexusError.Visibility      = Visibility.Collapsed;
        NexusList.Visibility       = Visibility.Collapsed;

        try
        {
            var repos = await _api.ListNexusReposAsync();

            if (repos.Count == 0)
            {
                NexusStatusText.Text = "No repositories indexed yet.";
            }
            else
            {
                NexusStatusText.Text = $"{repos.Count} repositor{(repos.Count == 1 ? "y" : "ies")} tracked";
                NexusList.ItemsSource = repos.Select(r => new NexusRepoRow(r)).ToList();
                NexusList.Visibility  = Visibility.Visible;
            }
        }
        catch (Exception ex)
        {
            NexusStatusText.Text = "";
            NexusStatusText.Visibility = Visibility.Collapsed;
            NexusError.Text = $"Could not load Nexus repos: {ex.Message}";
            NexusError.Visibility = Visibility.Visible;
        }
    }

    private async void RefreshNexus_Click(object sender, RoutedEventArgs e)
        => await LoadNexusAsync();

    // ── Danger zone ───────────────────────────────────────────────────────

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
            Title          = "Sign out",
            Content        = "This will remove your credentials from this device. You will need to re-pair to use the app.",
            PrimaryButtonText = "Sign out",
            CloseButtonText   = "Cancel",
            XamlRoot       = XamlRoot,
        };

        if (await confirm.ShowAsync() != ContentDialogResult.Primary) return;

        try
        {
            var tokens = await _api.ListTokensAsync();
            foreach (var t in tokens)
                await _api.RevokeTokenAsync(t.Id);
        }
        catch { }

        _creds.Clear();
        _api.Reconfigure();
        Frame.Navigate(typeof(PairingPage));
    }

    // ── Updates ───────────────────────────────────────────────────────────

    private async void CheckUpdate_Click(object sender, RoutedEventArgs e)
    {
        CheckUpdateBtn.IsEnabled   = false;
        UpdateStatusText.Text      = "Checking…";
        InstallUpdatePanel.Visibility = Visibility.Collapsed;
        _pendingUpdate             = null;

        try
        {
            var update = await _updater.CheckForUpdateAsync();
            if (update is null)
            {
                UpdateStatusText.Text = "You're up to date.";
            }
            else
            {
                _pendingUpdate        = update;
                UpdateStatusText.Text = $"v{update.Version} is available!";
                UpdateStatusText.Foreground = (Brush)App.Current.Resources["BaumSuccessBrush"];
                InstallUpdatePanel.Visibility = Visibility.Visible;
            }
        }
        catch (Exception ex)
        {
            UpdateStatusText.Text = $"Check failed: {ex.Message}";
        }
        finally
        {
            CheckUpdateBtn.IsEnabled = true;
        }
    }

    private async void InstallUpdate_Click(object sender, RoutedEventArgs e)
    {
        if (_pendingUpdate is null) return;
        InstallUpdateBtn.IsEnabled = false;
        CheckUpdateBtn.IsEnabled   = false;
        UpdateProgressText.Text    = "Downloading…";

        try
        {
            await _updater.DownloadAndInstallAsync(_pendingUpdate, new Progress<int>(pct =>
            {
                UpdateProgressText.Text = $"Downloading… {pct}%";
            }));
            // App will exit and relaunch after install
        }
        catch (Exception ex)
        {
            UpdateProgressText.Text    = $"Failed: {ex.Message}";
            InstallUpdateBtn.IsEnabled = true;
            CheckUpdateBtn.IsEnabled   = true;
        }
    }
}

// ── Token view-model ───────────────────────────────────────────────────────

internal record TokenRow(ApiToken Token)
{
    public string Id => Token.Id;
    public string Label => string.IsNullOrEmpty(Token.Name)
        ? $"Token …{Token.Id[^Math.Min(8, Token.Id.Length)..]}"
        : Token.Name;
    public string CreatedDisplay  => $"Created {Token.CreatedAt.ToLocalTime():MMM d, yyyy}";
    public string LastUsedDisplay => Token.LastUsedAt is null
        ? "Never used"
        : $"Last used {Token.LastUsedAt.Value.ToLocalTime():MMM d}";
}

// ── Nexus repo view-model ─────────────────────────────────────────────────

internal sealed class NexusRepoRow(NexusRepo repo)
{
    public string OwnerRepo        { get; } = repo.OwnerRepo;
    public string DefaultBranch    { get; } = repo.DefaultBranch;
    public string IndexStatusLabel { get; } = repo.IndexStatusLabel;
    public string PullStatusLabel  { get; } = repo.PullStatusLabel;
    public string LastIndexedDisplay { get; } = repo.LastIndexedDisplay;
    public string FileCountDisplay { get; } = repo.FileCountDisplay;

    // Index status colours
    public SolidColorBrush IndexStatusBg { get; } = IndexBg(repo.IndexStatus);
    public SolidColorBrush IndexStatusFg { get; } = IndexFg(repo.IndexStatus);

    // Pull status colours
    public SolidColorBrush PullStatusBg { get; } = PullBg(repo.PullStatus);
    public SolidColorBrush PullStatusFg { get; } = PullFg(repo.PullStatus);

    // ── colour helpers ────────────────────────────────────────────────────

    private static SolidColorBrush IndexBg(string s) => s switch
    {
        "indexed"  => Brush(0x0d, 0x28, 0x18),
        "indexing" => Brush(0x0d, 0x22, 0x3a),
        "pending"  => Brush(0x28, 0x20, 0x00),
        "error"    => Brush(0x2d, 0x0a, 0x0a),
        _          => Brush(0x1e, 0x29, 0x3b),
    };

    private static SolidColorBrush IndexFg(string s) => s switch
    {
        "indexed"  => Brush(0x4a, 0xde, 0x80),
        "indexing" => Brush(0x60, 0xa5, 0xfa),
        "pending"  => Brush(0xf5, 0x9e, 0x0b),
        "error"    => Brush(0xf8, 0x71, 0x71),
        _          => Brush(0x94, 0xa3, 0xb8),
    };

    private static SolidColorBrush PullBg(string? s) => s switch
    {
        "ok"      => Brush(0x0d, 0x28, 0x18),
        "pulling" => Brush(0x0d, 0x22, 0x3a),
        "error"   => Brush(0x2d, 0x0a, 0x0a),
        _         => Brush(0x1a, 0x1f, 0x2e),
    };

    private static SolidColorBrush PullFg(string? s) => s switch
    {
        "ok"      => Brush(0x4a, 0xde, 0x80),
        "pulling" => Brush(0x60, 0xa5, 0xfa),
        "error"   => Brush(0xf8, 0x71, 0x71),
        _         => Brush(0x64, 0x74, 0x8b),
    };

    private static SolidColorBrush Brush(byte r, byte g, byte b)
        => new(Color.FromArgb(255, r, g, b));
}
