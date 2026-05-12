using BaumAgent.Models;
using System.Net.Http.Json;
using System.Text.Json;

namespace BaumAgent.Services;

/// <summary>
/// HTTP API client for BaumAgent. Thread-safe. All methods throw HttpRequestException on non-2xx responses.
/// </summary>
public class BaumAgentApiClient
{
    private readonly CredentialService _creds;
    private HttpClient? _http;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private static async Task<T> ReadJsonAsync<T>(HttpResponseMessage r)
    {
        var body = await r.Content.ReadAsStringAsync();
        if (body.TrimStart().StartsWith('<'))
            throw new InvalidOperationException(
                "Server returned an HTML page instead of JSON. " +
                "The API may be unavailable or your session may have expired. " +
                "Try re-pairing in Settings if the problem persists.");
        return JsonSerializer.Deserialize<T>(body, JsonOpts)
            ?? throw new InvalidOperationException("Server returned an empty response.");
    }

    public BaumAgentApiClient(CredentialService creds)
    {
        _creds = creds;
    }

    private HttpClient Http()
    {
        if (_http is not null) return _http;
        var (url, token) = _creds.GetCredentials();
        _http = new HttpClient { BaseAddress = new Uri(url.TrimEnd('/') + '/') };
        _http.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");
        return _http;
    }

    /// <summary>Create a fresh unauthenticated client for health / pairing endpoints.</summary>
    public static HttpClient UnauthenticatedClient(string baseUrl) =>
        new() { BaseAddress = new Uri(baseUrl.TrimEnd('/') + '/') };

    public void Reconfigure()
    {
        _http?.Dispose();
        _http = null;
    }

    // ── Health ────────────────────────────────────────────────────────────

    public async Task<HealthResponse> GetHealthAsync(string baseUrl)
    {
        using var client = UnauthenticatedClient(baseUrl);
        var r = await client.GetAsync("api/health");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<HealthResponse>(r);
    }

    // ── Auth ──────────────────────────────────────────────────────────────

    public async Task<PairInitiateResponse> InitiatePairingAsync()
    {
        var r = await Http().PostAsync("api/auth/pair/initiate", null);
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<PairInitiateResponse>(r);
    }

    public async Task<PairCompleteResponse> CompletePairingAsync(string baseUrl, string code, string deviceName)
    {
        using var client = UnauthenticatedClient(baseUrl);
        var body = JsonContent.Create(new { code, device_name = deviceName });
        var r = await client.PostAsync("api/auth/pair/complete", body);
        if (!r.IsSuccessStatusCode)
        {
            var text = await r.Content.ReadAsStringAsync();
            throw new InvalidOperationException($"Pairing failed ({(int)r.StatusCode}): {text}");
        }
        return await ReadJsonAsync<PairCompleteResponse>(r);
    }

    public async Task<List<ApiToken>> ListTokensAsync()
    {
        var r = await Http().GetAsync("api/auth/tokens");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<List<ApiToken>>(r);
    }

    public async Task RevokeTokenAsync(string tokenId)
    {
        var r = await Http().DeleteAsync($"api/auth/tokens/{tokenId}");
        r.EnsureSuccessStatusCode();
    }

    // ── Push ──────────────────────────────────────────────────────────────

    public async Task RegisterPushTokenAsync(string platform, string token, string deviceLabel = "")
    {
        var body = JsonContent.Create(new { platform, token, device_label = deviceLabel });
        var r = await Http().PostAsync("api/push/register", body);
        r.EnsureSuccessStatusCode();
    }

    // ── Tasks ─────────────────────────────────────────────────────────────

    public async Task<TaskListResponse> ListTasksAsync(int page = 1, int pageSize = 25)
    {
        var r = await Http().GetAsync($"api/tasks?page={page}&page_size={pageSize}");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<TaskListResponse>(r);
    }

    public async Task<BaumTask> GetTaskAsync(string taskId)
    {
        var r = await Http().GetAsync($"api/tasks/{taskId}");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<BaumTask>(r);
    }

    /// <summary>
    /// Create a new task with optional image attachments, project assignment,
    /// and delivery mode.
    /// </summary>
    public async Task<BaumTask> CreateTaskAsync(
        string description,
        string taskType = "research",
        string llmBackend = "anthropic",
        string llmModel = "claude-opus-4-6",
        string repoUrl = "",
        string baseBranch = "main",
        string? projectId = null,
        string? targetOs = null,
        string? difficulty = null,
        string? deliveryMode = null,
        List<ImageAttachment>? images = null)
    {
        var form = new MultipartFormDataContent
        {
            { new StringContent(description), "description" },
            { new StringContent(taskType), "task_type" },
            { new StringContent(llmBackend), "llm_backend" },
            { new StringContent(llmModel), "llm_model" },
            { new StringContent(repoUrl), "repo_url" },
            { new StringContent(baseBranch), "base_branch" },
        };
        if (projectId is not null) form.Add(new StringContent(projectId), "project_id");
        if (targetOs is not null) form.Add(new StringContent(targetOs), "target_os");
        if (difficulty is not null) form.Add(new StringContent(difficulty), "difficulty");
        if (deliveryMode is not null) form.Add(new StringContent(deliveryMode), "delivery_mode");

        // Attach images as multipart file parts
        if (images is not null)
        {
            for (int i = 0; i < images.Count; i++)
            {
                var img = images[i];
                var content = new ByteArrayContent(img.Data);
                content.Headers.ContentType =
                    new System.Net.Http.Headers.MediaTypeHeaderValue(img.MimeType);
                form.Add(content, "images", img.DisplayName);
            }
        }

        var r = await Http().PostAsync("api/tasks", form);
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<BaumTask>(r);
    }

    public async Task<BaumTask> RetryTaskAsync(string taskId)
    {
        var r = await Http().PostAsync($"api/tasks/{taskId}/retry", null);
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<BaumTask>(r);
    }

    public async Task CancelTaskAsync(string taskId)
    {
        var r = await Http().PostAsync($"api/tasks/{taskId}/cancel", null);
        r.EnsureSuccessStatusCode();
    }

    public async Task DeleteTaskAsync(string taskId)
    {
        var r = await Http().DeleteAsync($"api/tasks/{taskId}");
        r.EnsureSuccessStatusCode();
    }

    public async Task<string> FixHealthScanAsync(string sourceTaskId)
    {
        var body = JsonContent.Create(new { source_task_id = sourceTaskId });
        var r = await Http().PostAsync("api/gitnexus/fix", body);
        r.EnsureSuccessStatusCode();
        return (await ReadJsonAsync<FixTaskResponse>(r)).TaskId;
    }

    public async Task<List<ExportFile>> ListExportsAsync(string taskId)
    {
        var r = await Http().GetAsync($"api/tasks/{taskId}/exports");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<List<ExportFile>>(r);
    }

    public async Task<(Stream Stream, string Filename)> DownloadExportAsync(string taskId)
    {
        var r = await Http().GetAsync($"api/tasks/{taskId}/download", HttpCompletionOption.ResponseHeadersRead);
        r.EnsureSuccessStatusCode();
        var filename = r.Content.Headers.ContentDisposition?.FileNameStar
            ?? r.Content.Headers.ContentDisposition?.FileName
            ?? "download";
        return (await r.Content.ReadAsStreamAsync(), filename.Trim('"'));
    }

    // ── Users ─────────────────────────────────────────────────────────────

    public async Task<User> GetMeAsync()
    {
        var r = await Http().GetAsync("api/me");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<User>(r);
    }

    // ── Projects ──────────────────────────────────────────────────────────

    public async Task<List<Project>> ListProjectsAsync()
    {
        var r = await Http().GetAsync("api/projects");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<List<Project>>(r);
    }

    // ── Queue + Models ────────────────────────────────────────────────────

    public async Task<QueueStatus> GetQueueAsync()
    {
        var r = await Http().GetAsync("api/queue");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<QueueStatus>(r);
    }

    public async Task<PortalSettings> GetSettingsAsync()
    {
        var r = await Http().GetAsync("api/settings");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<PortalSettings>(r);
    }

    public async Task<ModelsResponse> GetModelsAsync()
    {
        var r = await Http().GetAsync("api/models");
        r.EnsureSuccessStatusCode();
        return await ReadJsonAsync<ModelsResponse>(r);
    }
}
