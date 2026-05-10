using System.Diagnostics;
using System.Net.Http.Json;
using System.Reflection;
using System.Text.Json.Serialization;

namespace BaumAgent.Services;

public record UpdateInfo(string Version, string Notes, string DownloadUrl);

public class UpdateService
{
    private const string ApiUrl =
        "https://api.github.com/repos/Bruiserbaum/baumagent-clients/releases/latest";

    private static readonly HttpClient _http = new();

    static UpdateService()
    {
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("BaumAgentClient/1.0");
    }

    public static Version CurrentVersion =>
        Assembly.GetExecutingAssembly().GetName().Version ?? new Version(1, 0, 0);

    public async Task<UpdateInfo?> CheckForUpdateAsync()
    {
        try
        {
            var release = await _http.GetFromJsonAsync<GithubRelease>(ApiUrl);
            if (release is null) return null;

            var tag = release.TagName.TrimStart('v');
            if (!Version.TryParse(tag, out var latest)) return null;
            if (latest <= CurrentVersion) return null;

            // Find the Windows installer asset
            var asset = release.Assets.FirstOrDefault(a =>
                a.Name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase));
            if (asset is null) return null;

            return new UpdateInfo(tag, release.Body ?? "", asset.BrowserDownloadUrl);
        }
        catch
        {
            return null;
        }
    }

    public async Task DownloadAndInstallAsync(UpdateInfo update, IProgress<int>? progress = null)
    {
        var tempPath = Path.Combine(Path.GetTempPath(), $"BaumAgentSetup-{update.Version}.exe");

        using var response = await _http.GetAsync(
            update.DownloadUrl, HttpCompletionOption.ResponseHeadersRead);
        response.EnsureSuccessStatusCode();

        var total = response.Content.Headers.ContentLength ?? -1;
        var downloaded = 0L;

        await using var dest = File.Create(tempPath);
        await using var src = await response.Content.ReadAsStreamAsync();

        var buffer = new byte[81920];
        int read;
        while ((read = await src.ReadAsync(buffer)) > 0)
        {
            await dest.WriteAsync(buffer.AsMemory(0, read));
            downloaded += read;
            if (total > 0)
                progress?.Report((int)(downloaded * 100 / total));
        }

        dest.Close();

        // Run installer silently, then exit this instance
        var proc = Process.Start(new ProcessStartInfo(tempPath, "/S") { UseShellExecute = true });
        if (proc is null) throw new InvalidOperationException("Failed to launch installer.");
        await Task.Delay(500); // brief pause so installer process is established
        Microsoft.UI.Xaml.Application.Current.Exit();
    }
}

// GitHub releases API payload (only fields we need)
file record GithubRelease(
    [property: JsonPropertyName("tag_name")] string TagName,
    [property: JsonPropertyName("body")] string? Body,
    [property: JsonPropertyName("assets")] List<GithubAsset> Assets);

file record GithubAsset(
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("browser_download_url")] string BrowserDownloadUrl);
