using BaumAgent.Models;
using BaumAgent.Services;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using Windows.UI;

namespace BaumAgent.Pages;

public sealed partial class HistoryPage : Page
{
    private readonly BaumAgentApiClient _api = App.GetService<BaumAgentApiClient>();

    private List<HistoryTaskRow> _allRows = [];
    private string? _activeProjectId;

    public HistoryPage() => InitializeComponent();

    protected override async void OnNavigatedTo(NavigationEventArgs e)
        => await LoadAsync();

    private async void Refresh_Click(object sender, RoutedEventArgs e)
        => await LoadAsync();

    private async Task LoadAsync()
    {
        RefreshBtn.IsEnabled = false;
        StatusText.Text = "Loading…";
        StatusText.Foreground = (Brush)App.Current.Resources["BaumSubtextBrush"];
        _allRows = [];
        _activeProjectId = null;
        ClearFilterBtn.Visibility = Visibility.Collapsed;
        FilterLabel.Text = "";

        try
        {
            // Load tasks first (essential)
            var response = await _api.ListTasksAsync(page: 1, pageSize: 200);
            var terminal = response.Items
                .Where(t => t.IsTerminal)
                .ToList();

            _allRows = terminal.Select(t => new HistoryTaskRow(t)).ToList();

            // Load projects (non-fatal if endpoint is unavailable)
            try
            {
                var projects = await _api.ListProjectsAsync();
                var projectCards = projects
                    .OrderBy(p => p.Position)
                    .Select(p => new ProjectCard(
                        p.Id, p.Name, p.Color,
                        terminal.Count(t => t.ProjectId == p.Id)))
                    .ToList();

                if (projectCards.Count > 0)
                {
                    ProjectsList.ItemsSource = projectCards;
                    ProjectsPanel.Visibility = Visibility.Visible;
                }
                else
                {
                    ProjectsPanel.Visibility = Visibility.Collapsed;
                }
            }
            catch
            {
                ProjectsPanel.Visibility = Visibility.Collapsed;
            }

            ApplyFilter();
            StatusText.Text = $"{_allRows.Count} finished tasks";
        }
        catch (Exception ex)
        {
            // Make auth / session errors obvious so the user knows what to do.
            bool isAuthIssue = ex.Message.Contains("HTML") ||
                               ex.Message.Contains("session") ||
                               ex.Message.Contains("expired") ||
                               ex.Message.Contains("401") ||
                               ex.Message.Contains("403");

            StatusText.Foreground = (Brush)App.Current.Resources["BaumDangerBrush"];
            StatusText.Text = isAuthIssue
                ? $"Session error — {ex.Message} Go to Settings → Re-pair device."
                : $"Error: {ex.Message}";
        }
        finally
        {
            RefreshBtn.IsEnabled = true;
        }
    }

    private void ApplyFilter()
    {
        if (_activeProjectId is null)
        {
            TasksList.ItemsSource = _allRows;
        }
        else
        {
            TasksList.ItemsSource = _allRows
                .Where(r => r.ProjectId == _activeProjectId)
                .ToList();
        }
    }

    private void Project_Click(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not ProjectCard card) return;

        if (_activeProjectId == card.Id)
        {
            // Second click → clear filter
            _activeProjectId = null;
            FilterLabel.Text = "";
            ClearFilterBtn.Visibility = Visibility.Collapsed;
        }
        else
        {
            _activeProjectId = card.Id;
            FilterLabel.Text = $"— {card.Name}";
            ClearFilterBtn.Visibility = Visibility.Visible;
        }
        ApplyFilter();
    }

    private void ClearFilter_Click(object sender, RoutedEventArgs e)
    {
        _activeProjectId = null;
        FilterLabel.Text = "";
        ClearFilterBtn.Visibility = Visibility.Collapsed;
        ApplyFilter();
    }

    private void Task_Click(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not HistoryTaskRow row) return;
        Frame.Navigate(typeof(TaskDetailPage), row.TaskId);
    }
}

// ── View models ────────────────────────────────────────────────────────────

internal sealed class ProjectCard(string id, string name, string colorHex, int taskCount)
{
    public string Id { get; } = id;
    public string Name { get; } = name;
    public string TaskCountLabel { get; } = taskCount == 1 ? "1 task" : $"{taskCount} tasks";

    public SolidColorBrush AccentColor { get; } = ParseBrush(colorHex);

    private static SolidColorBrush ParseBrush(string hex)
    {
        try
        {
            hex = hex.TrimStart('#');
            if (hex.Length == 6)
            {
                var r = Convert.ToByte(hex[..2], 16);
                var g = Convert.ToByte(hex[2..4], 16);
                var b = Convert.ToByte(hex[4..6], 16);
                return new SolidColorBrush(Color.FromArgb(255, r, g, b));
            }
        }
        catch { }
        return new SolidColorBrush(Color.FromArgb(255, 59, 130, 246));
    }
}

internal sealed class HistoryTaskRow(BaumTask task)
{
    public string TaskId { get; } = task.Id;
    public string? ProjectId { get; } = task.ProjectId;
    public string Description { get; } = task.Description;

    // Status
    public string StatusLabel { get; } = task.Status.ToUpper();
    public SolidColorBrush StatusBg { get; } = StatusBackground(task.Status);
    public SolidColorBrush StatusFg { get; } = StatusForeground(task.Status);

    // Type
    public string TypeLabel { get; } = TypeDisplay(task.TaskType);
    public SolidColorBrush TypeBg { get; } = TypeBackground(task.TaskType);
    public SolidColorBrush TypeFg { get; } = TypeForeground(task.TaskType);

    // Date
    public string DateLabel { get; } = task.UpdatedAt.ToLocalTime().ToString("MMM d, yyyy");

    private static SolidColorBrush StatusBackground(string s) => s switch
    {
        "complete"  => Brush(0x0d, 0x28, 0x18),
        "failed"    => Brush(0x2d, 0x0a, 0x0a),
        "cancelled" => Brush(0x2d, 0x1f, 0x00),
        _           => Brush(0x1e, 0x29, 0x3b),
    };

    private static SolidColorBrush StatusForeground(string s) => s switch
    {
        "complete"  => Brush(0x4a, 0xde, 0x80),
        "failed"    => Brush(0xf8, 0x71, 0x71),
        "cancelled" => Brush(0xf5, 0x9e, 0x0b),
        _           => Brush(0x94, 0xa3, 0xb8),
    };

    private static string TypeDisplay(string t) => t switch
    {
        "research"            => "RESEARCH",
        "deep_research"       => "DEEP RESEARCH",
        "coding"              => "SCRIPT",
        "structured_document" => "DOC",
        "instructions"        => "INSTRUCTIONS",
        _                     => "GITHUB",
    };

    private static SolidColorBrush TypeBackground(string t) => t switch
    {
        "research" or "deep_research" => Brush(0x0d, 0x33, 0x40),
        "coding"                      => Brush(0x0d, 0x2d, 0x1a),
        "structured_document"         => Brush(0x2d, 0x1f, 0x00),
        "instructions"                => Brush(0x0d, 0x1f, 0x33),
        _                             => Brush(0x1e, 0x1b, 0x3a),
    };

    private static SolidColorBrush TypeForeground(string t) => t switch
    {
        "research" or "deep_research" => Brush(0x38, 0xbd, 0xf8),
        "coding"                      => Brush(0x4a, 0xde, 0x80),
        "structured_document"         => Brush(0xf5, 0x9e, 0x0b),
        "instructions"                => Brush(0x7d, 0xd3, 0xfc),
        _                             => Brush(0xa7, 0x8b, 0xfa),
    };

    private static SolidColorBrush Brush(byte r, byte g, byte b)
        => new(Color.FromArgb(255, r, g, b));
}
