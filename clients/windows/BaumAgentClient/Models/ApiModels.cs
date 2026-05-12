using System.Text.Json.Serialization;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Storage.Streams;

namespace BaumAgent.Models;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

public enum TaskStatus { Queued, Running, Complete, Failed, Cancelled }

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

public record PairInitiateResponse(
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("expires_in")] int ExpiresIn,
    [property: JsonPropertyName("pair_url")] string PairUrl);

public record PairCompleteResponse(
    [property: JsonPropertyName("token")] string Token,
    [property: JsonPropertyName("token_id")] string TokenId,
    [property: JsonPropertyName("user_id")] string UserId,
    [property: JsonPropertyName("user_email")] string UserEmail,
    [property: JsonPropertyName("user_display_name")] string UserDisplayName);

public record ApiToken(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("created_at")] DateTime CreatedAt,
    [property: JsonPropertyName("last_used_at")] DateTime? LastUsedAt,
    [property: JsonPropertyName("expires_at")] DateTime? ExpiresAt);

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

public record BaumTask(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("created_at")] DateTime CreatedAt,
    [property: JsonPropertyName("updated_at")] DateTime UpdatedAt,
    [property: JsonPropertyName("description")] string Description,
    [property: JsonPropertyName("repo_url")] string RepoUrl,
    [property: JsonPropertyName("base_branch")] string BaseBranch,
    [property: JsonPropertyName("llm_backend")] string LlmBackend,
    [property: JsonPropertyName("llm_model")] string LlmModel,
    [property: JsonPropertyName("status")] string Status,
    [property: JsonPropertyName("log")] string Log,
    [property: JsonPropertyName("task_type")] string TaskType,
    [property: JsonPropertyName("branch_name")] string? BranchName,
    [property: JsonPropertyName("pr_url")] string? PrUrl,
    [property: JsonPropertyName("pr_number")] int? PrNumber,
    [property: JsonPropertyName("commit_sha")] string? CommitSha,
    [property: JsonPropertyName("error_message")] string? ErrorMessage,
    [property: JsonPropertyName("output_file")] string? OutputFile,
    [property: JsonPropertyName("output_format")] string? OutputFormat,
    [property: JsonPropertyName("user_id")] string? UserId,
    [property: JsonPropertyName("project_id")] string? ProjectId,
    [property: JsonPropertyName("extra_data")] string ExtraData,
    [property: JsonPropertyName("progress_percent")] int? ProgressPercent)
{
    public bool IsTerminal =>
        Status is "complete" or "failed" or "cancelled";

    public bool IsRunning => Status == "running";
}

public record TaskListResponse(
    [property: JsonPropertyName("items")] List<BaumTask> Items,
    [property: JsonPropertyName("total")] int Total,
    [property: JsonPropertyName("page")] int Page,
    [property: JsonPropertyName("page_size")] int PageSize);

public record ExportFile(
    [property: JsonPropertyName("filename")] string Filename,
    [property: JsonPropertyName("size_bytes")] long SizeBytes,
    [property: JsonPropertyName("mime_type")] string MimeType,
    [property: JsonPropertyName("created_at")] DateTime CreatedAt,
    [property: JsonPropertyName("download_url")] string DownloadUrl)
{
    public string SizeDisplay => SizeBytes switch
    {
        < 1024 => $"{SizeBytes} B",
        < 1024 * 1024 => $"{SizeBytes / 1024.0:F1} KB",
        _ => $"{SizeBytes / (1024.0 * 1024):F1} MB",
    };
}

// ---------------------------------------------------------------------------
// Projects
// ---------------------------------------------------------------------------

public record Project(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("user_id")] string UserId,
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("color")] string Color,
    [property: JsonPropertyName("position")] int Position,
    [property: JsonPropertyName("created_at")] DateTime CreatedAt);

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

public record User(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("email")] string Email,
    [property: JsonPropertyName("display_name")] string DisplayName,
    [property: JsonPropertyName("avatar_url")] string? AvatarUrl,
    [property: JsonPropertyName("created_at")] DateTime CreatedAt);

// ---------------------------------------------------------------------------
// Queue + Health
// ---------------------------------------------------------------------------

public record QueueStatus(
    [property: JsonPropertyName("queued")] List<string> Queued,
    [property: JsonPropertyName("running")] List<string> Running);

public record HealthResponse(
    [property: JsonPropertyName("status")] string Status);

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

public record PortalSettings(
    [property: JsonPropertyName("default_llm_backend")] string DefaultLlmBackend,
    [property: JsonPropertyName("default_llm_model")] string DefaultLlmModel,
    [property: JsonPropertyName("chat_backend")] string ChatBackend,
    [property: JsonPropertyName("chat_model")] string ChatModel,
    [property: JsonPropertyName("research_backend")] string ResearchBackend,
    [property: JsonPropertyName("research_model")] string ResearchModel,
    [property: JsonPropertyName("code_backend")] string CodeBackend,
    [property: JsonPropertyName("code_model")] string CodeModel);

public record ModelsResponse(
    [property: JsonPropertyName("anthropic")] List<string> Anthropic,
    [property: JsonPropertyName("openai")] List<string> OpenAi,
    [property: JsonPropertyName("ollama")] List<string> Ollama);

// ---------------------------------------------------------------------------
// Git Nexus
// ---------------------------------------------------------------------------

/// <summary>
/// Represents a single repository tracked by the Git Nexus indexing system.
/// Maps to the GitNexusRepo schema returned by GET /api/gitnexus/repos.
/// </summary>
public record NexusRepo(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("repo_url")] string RepoUrl,
    [property: JsonPropertyName("default_branch")] string DefaultBranch,
    [property: JsonPropertyName("index_status")] string IndexStatus,
    [property: JsonPropertyName("pull_status")] string? PullStatus,
    [property: JsonPropertyName("last_indexed_at")] DateTime? LastIndexedAt,
    [property: JsonPropertyName("last_pulled_at")] DateTime? LastPulledAt,
    [property: JsonPropertyName("file_count")] int? FileCount,
    [property: JsonPropertyName("error_message")] string? ErrorMessage)
{
    /// <summary>Short repo name extracted from the URL for display purposes.</summary>
    public string ShortName
    {
        get
        {
            var url = RepoUrl.TrimEnd('/');
            var slash = url.LastIndexOf('/');
            return slash >= 0 ? url[(slash + 1)..] : url;
        }
    }

    /// <summary>Owner/repo path (last two segments of the URL).</summary>
    public string OwnerRepo
    {
        get
        {
            var url = RepoUrl.TrimEnd('/');
            var parts = url.Split('/');
            return parts.Length >= 2
                ? $"{parts[^2]}/{parts[^1]}"
                : url;
        }
    }

    /// <summary>Human-readable index status label.</summary>
    public string IndexStatusLabel => IndexStatus switch
    {
        "indexed"   => "Indexed",
        "indexing"  => "Indexing…",
        "pending"   => "Pending",
        "error"     => "Error",
        "never"     => "Not indexed",
        _           => IndexStatus,
    };

    /// <summary>Human-readable pull status label.</summary>
    public string PullStatusLabel => PullStatus switch
    {
        "ok"        => "Up to date",
        "pulling"   => "Pulling…",
        "error"     => "Pull error",
        null or ""  => "—",
        _           => PullStatus,
    };

    public string LastIndexedDisplay => LastIndexedAt is null
        ? "Never"
        : LastIndexedAt.Value.ToLocalTime().ToString("MMM d, yyyy HH:mm");

    public string FileCountDisplay => FileCount is null
        ? "—"
        : $"{FileCount:N0} files";
}

// ---------------------------------------------------------------------------
// WebSocket frames
// ---------------------------------------------------------------------------

public record WsFrame(
    [property: JsonPropertyName("type")] string Type,
    [property: JsonPropertyName("data")] System.Text.Json.JsonElement Data);

public record WsDonePayload(
    [property: JsonPropertyName("status")] string Status,
    [property: JsonPropertyName("output_file")] string? OutputFile,
    [property: JsonPropertyName("pr_url")] string? PrUrl,
    [property: JsonPropertyName("error")] string? Error);

public record FixTaskResponse(
    [property: JsonPropertyName("task_id")] string TaskId,
    [property: JsonPropertyName("repo_url")] string RepoUrl);

// ---------------------------------------------------------------------------
// Image attachment (used by TaskCreatePage and BaumAgentApiClient)
// ---------------------------------------------------------------------------

/// <summary>
/// Represents an image attachment for the task creation form.
/// Holds the raw bytes and provides display helpers for the XAML UI.
/// </summary>
public class ImageAttachment
{
    public string DisplayName { get; }
    public byte[] Data { get; }
    public string MimeType { get; }

    public string SizeDisplay => Data.Length switch
    {
        < 1024 => $"{Data.Length} B",
        < 1024 * 1024 => $"{Data.Length / 1024.0:F1} KB",
        _ => $"{Data.Length / (1024.0 * 1024):F1} MB",
    };

    public ImageAttachment(string displayName, byte[] data, string mimeType)
    {
        DisplayName = displayName;
        Data = data;
        MimeType = mimeType;
    }

    public BitmapImage? Thumbnail { get; set; }

    public static async Task<ImageAttachment> FromStorageFileAsync(Windows.Storage.StorageFile file)
    {
        var props = await file.GetBasicPropertiesAsync();
        using var stream = await file.OpenReadAsync();
        var buffer = new byte[stream.Size];
        using var reader = new DataReader(stream);
        await reader.LoadAsync((uint)stream.Size);
        reader.ReadBytes(buffer);

        var mime = file.ContentType;
        if (string.IsNullOrEmpty(mime)) mime = "image/png";

        var attachment = new ImageAttachment(file.Name, buffer, mime);

        // Build thumbnail on UI thread
        var bmp = new BitmapImage();
        stream.Seek(0);
        await bmp.SetSourceAsync(stream);
        attachment.Thumbnail = bmp;

        return attachment;
    }

    public static async Task<ImageAttachment> FromClipboardBitmapAsync(
        Windows.Storage.Streams.IRandomAccessStreamReference reference,
        string suggestedName = "clipboard.png")
    {
        using var stream = await reference.OpenReadAsync();
        var buffer = new byte[stream.Size];
        using var reader = new DataReader(stream);
        await reader.LoadAsync((uint)stream.Size);
        reader.ReadBytes(buffer);

        var attachment = new ImageAttachment(suggestedName, buffer, "image/png");

        var bmp = new BitmapImage();
        stream.Seek(0);
        await bmp.SetSourceAsync(stream);
        attachment.Thumbnail = bmp;

        return attachment;
    }
}
