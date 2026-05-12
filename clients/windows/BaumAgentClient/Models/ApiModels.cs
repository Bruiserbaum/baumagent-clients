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

    /// <summary>
    /// Generates a thumbnail BitmapImage from the raw bytes for display
    /// in the image attachment list. Returns null if decoding fails.
    /// </summary>
    public BitmapImage? Thumbnail
    {
        get
        {
            try
            {
                var bmp = new BitmapImage();
                using var ms = new InMemoryRandomAccessStream();
                ms.AsStreamForWrite().Write(Data, 0, Data.Length);
                ms.Seek(0);
                bmp.SetSource(ms);
                return bmp;
            }
            catch
            {
                return null;
            }
        }
    }

    public ImageAttachment(string displayName, byte[] data, string mimeType)
    {
        DisplayName = displayName;
        Data = data;
        MimeType = mimeType;
    }
}
