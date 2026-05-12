using BaumAgent.Models;
using BaumAgent.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using System.Collections.ObjectModel;
using Windows.UI;

namespace BaumAgent.Pages;

public sealed partial class TaskListPage : Page
{
    private readonly BaumAgentApiClient _api = App.GetService<BaumAgentApiClient>();
    private readonly ObservableCollection<TaskRow> _rows = [];
    private int _page = 1;
    private int _total;
    private const int PageSize = 25;
    private System.Threading.Timer? _refreshTimer;
    private bool _isLoading;

    public TaskListPage()
    {
        InitializeComponent();
        TaskListView.ItemsSource = _rows;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        await LoadAsync();
        // Auto-refresh the full task list (including statuses) every 5 seconds
        // so running tasks update without manual intervention.
        _refreshTimer = new System.Threading.Timer(
            _ =>
            {
                // Fire-and-forget on the dispatcher; swallow exceptions to
                // avoid crashing if the page has already navigated away.
                try
                {
                    DispatcherQueue?.TryEnqueue(async () =>
                    {
                        try { await LoadAsync(); }
                        catch { /* timer refresh is best-effort */ }
                    });
                }
                catch { }
            },
            null, TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5));
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _refreshTimer?.Dispose();
        _refreshTimer = null;
    }

    private async Task LoadAsync()
    {
        // Guard against overlapping loads (timer + manual refresh).
        if (_isLoading) return;
        _isLoading = true;

        try
        {
            var (tasksTask, queueTask) = (
                _api.ListTasksAsync(_page, PageSize),
                _api.GetQueueAsync());
            await Task.WhenAll(tasksTask, queueTask);

            var resp = await tasksTask;
            var queue = await queueTask;
            _total = resp.Total;

            // Only rebuild the list if the data actually changed, to avoid
            // flickering and losing the user's scroll position.
            var newRows = resp.Items.Select(t => new TaskRow(t)).ToList();
            if (!RowsEqual(_rows, newRows))
            {
                _rows.Clear();
                foreach (var r in newRows)
                    _rows.Add(r);
            }

            QueuedCount.Text = $"Queued: {queue.Queued.Count}";
            RunningCount.Text = $"Running: {queue.Running.Count}";
            TotalCount.Text = $"Total: {_total}";
            PageLabel.Text = $"Page {_page} of {Math.Max(1, (int)Math.Ceiling(_total / (double)PageSize))}";
            PrevPage.IsEnabled = _page > 1;
            NextPage.IsEnabled = _page * PageSize < _total;

            // Clear any previous error indicator
            RefreshErrorText.Text = "";
            RefreshErrorText.Visibility = Visibility.Collapsed;
        }
        catch (Exception ex)
        {
            // Surface errors so the user knows refresh isn't silently failing
            RefreshErrorText.Text = $"Refresh failed: {ex.Message}";
            RefreshErrorText.Visibility = Visibility.Visible;
        }
        finally
        {
            _isLoading = false;
        }
    }

    /// <summary>
    /// Compares two row collections by task ID + status to avoid unnecessary UI rebuilds.
    /// </summary>
    private static bool RowsEqual(ObservableCollection<TaskRow> existing, List<TaskRow> incoming)
    {
        if (existing.Count != incoming.Count) return false;
        for (int i = 0; i < existing.Count; i++)
        {
            if (existing[i].Task.Id != incoming[i].Task.Id ||
                existing[i].Task.Status != incoming[i].Task.Status ||
                existing[i].Task.ProgressPercent != incoming[i].Task.ProgressPercent)
                return false;
        }
        return true;
    }

    private void TaskList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (TaskListView.SelectedItem is TaskRow row)
            Frame.Navigate(typeof(TaskDetailPage), row.Task.Id);
    }

    private async void Refresh_Click(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
        => await LoadAsync();

    private async void PrevPage_Click(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        if (_page > 1) { _page--; await LoadAsync(); }
    }

    private async void NextPage_Click(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        if (_page * PageSize < _total) { _page++; await LoadAsync(); }
    }
}

// Thin display wrapper so XAML DataTemplate can bind computed props
internal record TaskRow(BaumTask Task)
{
    public string Description => Task.Description;
    public string TaskType => Task.TaskType;
    public string Status => Task.Status.ToUpper();
    public string CreatedAt => Task.CreatedAt.ToLocalTime().ToString("MMM d, HH:mm");

    public Color StatusColor => Task.Status switch
    {
        "complete" => Color.FromArgb(255, 74, 222, 128),
        "failed" => Color.FromArgb(255, 248, 113, 113),
        "cancelled" => Color.FromArgb(255, 245, 158, 11),
        "running" => Color.FromArgb(255, 96, 165, 250),
        _ => Color.FromArgb(255, 100, 116, 139),
    };
}
