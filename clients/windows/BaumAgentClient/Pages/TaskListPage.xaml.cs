using BaumAgent.Models;
using BaumAgent.Services;
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

    public TaskListPage()
    {
        InitializeComponent();
        TaskListView.ItemsSource = _rows;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        await LoadAsync();
        _refreshTimer = new System.Threading.Timer(
            async _ => await DispatcherQueue.EnqueueAsync(RefreshQueue),
            null, TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5));
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _refreshTimer?.Dispose();
        _refreshTimer = null;
    }

    private async Task LoadAsync()
    {
        try
        {
            var (tasksTask, queueTask) = (
                _api.ListTasksAsync(_page, PageSize),
                _api.GetQueueAsync());
            await Task.WhenAll(tasksTask, queueTask);

            var resp = await tasksTask;
            var queue = await queueTask;
            _total = resp.Total;

            _rows.Clear();
            foreach (var t in resp.Items)
                _rows.Add(new TaskRow(t));

            QueuedCount.Text = $"Queued: {queue.Queued.Count}";
            RunningCount.Text = $"Running: {queue.Running.Count}";
            TotalCount.Text = $"Total: {_total}";
            PageLabel.Text = $"Page {_page} of {Math.Max(1, (int)Math.Ceiling(_total / (double)PageSize))}";
            PrevPage.IsEnabled = _page > 1;
            NextPage.IsEnabled = _page * PageSize < _total;
        }
        catch { /* show error inline in production */ }
    }

    private async Task RefreshQueue()
    {
        try
        {
            var queue = await _api.GetQueueAsync();
            QueuedCount.Text = $"Queued: {queue.Queued.Count}";
            RunningCount.Text = $"Running: {queue.Running.Count}";
        }
        catch { }
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
