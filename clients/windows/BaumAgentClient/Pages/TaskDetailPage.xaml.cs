using BaumAgent.Models;
using BaumAgent.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using System.Text.Json;
using Windows.Storage;
using Windows.Storage.Pickers;

namespace BaumAgent.Pages;

public sealed partial class TaskDetailPage : Page
{
    private readonly BaumAgentApiClient _api = App.GetService<BaumAgentApiClient>();
    private readonly WebSocketService _ws = App.GetService<WebSocketService>();
    private readonly PushService _push = App.GetService<PushService>();
    private CancellationTokenSource? _wsCts;
    private string? _taskId;
    private BaumTask? _task;

    public TaskDetailPage() => InitializeComponent();

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        _taskId = e.Parameter as string;
        if (_taskId is null) return;

        try
        {
            _task = await _api.GetTaskAsync(_taskId);
            PopulateHeader(_task);

            if (_task.IsTerminal)
            {
                LogText.Text = _task.Log;
                await LoadExports();
            }
            else
            {
                StartLogStream();
            }
        }
        catch (Exception ex)
        {
            LogText.Text = $"Error loading task: {ex.Message}";
        }
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _wsCts?.Cancel();
        _wsCts = null;
    }

    private void PopulateHeader(BaumTask t)
    {
        DescriptionText.Text = t.Description;
        TypeText.Text = t.TaskType;
        ModelText.Text = $"{t.LlmBackend} / {t.LlmModel}";
        SetStatus(t.Status);
        UpdateButtons(t);

        if (t.PrUrl is not null)
        {
            PrLink.Content = $"PR #{t.PrNumber} →";
            PrLink.NavigateUri = new Uri(t.PrUrl);
            PrLink.Visibility = Visibility.Visible;
        }
    }

    private void SetStatus(string status)
    {
        StatusText.Text = status.ToUpper();
        StatusText.Foreground = status switch
        {
            "complete" => (Microsoft.UI.Xaml.Media.Brush)App.Current.Resources["BaumSuccessBrush"],
            "failed" => (Microsoft.UI.Xaml.Media.Brush)App.Current.Resources["BaumDangerBrush"],
            "cancelled" => (Microsoft.UI.Xaml.Media.Brush)App.Current.Resources["BaumWarningBrush"],
            "running" => (Microsoft.UI.Xaml.Media.Brush)App.Current.Resources["BaumAccentBrush"],
            _ => (Microsoft.UI.Xaml.Media.Brush)App.Current.Resources["BaumSubtextBrush"],
        };
    }

    private void UpdateButtons(BaumTask t)
    {
        CancelBtn.IsEnabled = t.Status is "queued" or "running";
        RetryBtn.IsEnabled = t.IsTerminal;
        DownloadBtn.IsEnabled = t.IsTerminal && t.TaskType != "code";

        bool isHealthScan = t.Description?.StartsWith("[Health Scan]", StringComparison.Ordinal) == true;
        FixIssuesPanel.Visibility = isHealthScan && t.Status == "complete"
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private void StartLogStream()
    {
        if (_taskId is null) return;
        // Cancel any previous stream before starting a new one (e.g. on Retry)
        _wsCts?.Cancel();
        _wsCts = new CancellationTokenSource();
        var ct = _wsCts.Token;

        _ = Task.Run(async () =>
        {
            var logBuffer = new System.Text.StringBuilder(_task?.Log ?? "");

            await foreach (var frame in _ws.StreamAsync(_taskId, ct))
            {
                await DispatcherQueue.EnqueueAsync(() =>
                {
                    switch (frame.Type)
                    {
                        case "log":
                            logBuffer.Append(frame.Data.GetString());
                            LogText.Text = logBuffer.ToString();
                            LogScroll.ScrollToVerticalOffset(double.MaxValue);
                            break;

                        case "status":
                            var newStatus = frame.Data.GetString() ?? "";
                            SetStatus(newStatus);
                            break;

                        case "progress":
                            var pct = frame.Data.GetInt32();
                            ProgressBar.Value = pct;
                            ProgressBar.Visibility = Visibility.Visible;
                            break;

                        case "done":
                            ProgressBar.Visibility = Visibility.Collapsed;
                            var done = frame.Data.Deserialize<WsDonePayload>();
                            if (done is not null)
                            {
                                SetStatus(done.Status);
                                if (done.Status == "complete")
                                {
                                    _ = LoadExports();
                                    _push.ShowLocalNotification(
                                        "Task complete",
                                        _task?.Description?[..Math.Min(80, _task.Description.Length)] ?? "",
                                        _taskId);
                                }
                                else if (done.Error is not null)
                                {
                                    _push.ShowLocalNotification("Task failed", done.Error, _taskId);
                                }
                            }
                            RetryBtn.IsEnabled = true;
                            CancelBtn.IsEnabled = false;
                            break;
                    }
                });
            }
        }, ct);
    }

    private async Task LoadExports()
    {
        if (_taskId is null) return;
        try
        {
            var exports = await _api.ListExportsAsync(_taskId);
            if (exports.Count > 0)
            {
                ExportsList.ItemsSource = exports;
                ExportsPanel.Visibility = Visibility.Visible;
                DownloadBtn.IsEnabled = true;
            }
        }
        catch { }
    }

    private async void Cancel_Click(object sender, RoutedEventArgs e)
    {
        if (_taskId is null) return;
        try
        {
            await _api.CancelTaskAsync(_taskId);
            CancelBtn.IsEnabled = false;
        }
        catch (Exception ex)
        {
            await ShowError("Cancel failed", ex.Message);
        }
    }

    private async void Retry_Click(object sender, RoutedEventArgs e)
    {
        if (_taskId is null) return;
        try
        {
            var t = await _api.RetryTaskAsync(_taskId);
            _task = t;
            LogText.Text = "";
            ProgressBar.Value = 0;
            ExportsPanel.Visibility = Visibility.Collapsed;
            UpdateButtons(t);
            SetStatus(t.Status);
            StartLogStream();
        }
        catch (Exception ex)
        {
            await ShowError("Retry failed", ex.Message);
        }
    }

    private async void Download_Click(object sender, RoutedEventArgs e)
    {
        if (_taskId is null) return;
        await DownloadFileAsync(_taskId);
    }

    private async void ExportDownload_Click(object sender, RoutedEventArgs e)
    {
        if (_taskId is null) return;
        await DownloadFileAsync(_taskId);
    }

    private async Task DownloadFileAsync(string taskId)
    {
        try
        {
            var (stream, filename) = await _api.DownloadExportAsync(taskId);

            var picker = new FileSavePicker();
            picker.SuggestedFileName = filename;
            picker.FileTypeChoices.Add("All files", ["*"]);

            // WinUI 3 unpackaged: must initialise picker with window handle
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow!);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

            var file = await picker.PickSaveFileAsync();
            if (file is null) return;

            using var dest = await file.OpenStreamForWriteAsync();
            await stream.CopyToAsync(dest);
        }
        catch (Exception ex)
        {
            await ShowError("Download failed", ex.Message);
        }
    }

    private async void FixIssues_Click(object sender, RoutedEventArgs e)
    {
        if (_taskId is null) return;
        FixIssuesBtn.IsEnabled = false;
        FixStatusText.Text = "Creating fix task…";
        FixStatusText.Visibility = Visibility.Visible;
        try
        {
            var newTaskId = await _api.FixHealthScanAsync(_taskId);
            FixStatusText.Text = $"Fix task queued — find it in the task list tagged [Health Fix].";
            FixIssuesBtn.Visibility = Visibility.Collapsed;
        }
        catch (Exception ex)
        {
            FixStatusText.Text = $"Failed: {ex.Message}";
            FixIssuesBtn.IsEnabled = true;
        }
    }

    private async Task ShowError(string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            CloseButtonText = "OK",
            XamlRoot = XamlRoot,
        };
        await dialog.ShowAsync();
    }
}
