using BaumAgent.Models;
using BaumAgent.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Navigation;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.Storage.Streams;
using Windows.System;

namespace BaumAgent.Pages;

public sealed partial class TaskCreatePage : Page
{
    private readonly BaumAgentApiClient _api = App.GetService<BaumAgentApiClient>();
    private readonly VoiceService _voice = App.GetService<VoiceService>();

    private List<Project> _projects = [];
    private readonly List<ImageAttachment> _images = [];

    public TaskCreatePage()
    {
        InitializeComponent();
        TypeBox.SelectionChanged += TypeBox_SelectionChanged;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        await LoadProjectsAsync();
    }

    // ── Project loading ───────────────────────────────────────────────────

    private async Task LoadProjectsAsync()
    {
        try
        {
            _projects = await _api.ListProjectsAsync();

            // Build the project ComboBox items
            ProjectBox.Items.Clear();
            ProjectBox.Items.Add(new ComboBoxItem { Content = "(None)", Tag = (string?)null });
            foreach (var p in _projects.OrderBy(p => p.Position))
            {
                ProjectBox.Items.Add(new ComboBoxItem { Content = p.Name, Tag = p.Id });
            }
            ProjectBox.SelectedIndex = 0;
        }
        catch
        {
            // Projects endpoint may not be available; degrade gracefully.
            ProjectBox.Items.Clear();
            ProjectBox.Items.Add(new ComboBoxItem { Content = "(None)", Tag = (string?)null });
            ProjectBox.SelectedIndex = 0;
        }
    }

    // ── Task type visibility ──────────────────────────────────────────────

    private void TypeBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var tag = (TypeBox.SelectedItem as ComboBoxItem)?.Tag as string;
        CodeOptions.Visibility = tag == "code" ? Visibility.Visible : Visibility.Collapsed;
        InstructionsOptions.Visibility = tag == "instructions" ? Visibility.Visible : Visibility.Collapsed;

        // Show delivery mode options for research-type tasks
        DeliveryOptions.Visibility = tag is "research" or "deep_research" or "structured_document"
            ? Visibility.Visible
            : Visibility.Collapsed;

        DescriptionBox.PlaceholderText = tag switch
        {
            "instructions" => "Describe the technology or process to write step-by-step instructions for…",
            "code"         => "Describe what the agent should do in the repository…",
            _              => "Describe the task…",
        };
    }

    // ── Voice dictation ───────────────────────────────────────────────────

    private async void Voice_Click(object sender, RoutedEventArgs e)
    {
        VoiceBtn.IsEnabled = false;
        VoiceStatus.Text = "Listening…";

        try
        {
            var result = await _voice.DictateAsync();
            if (result is not null)
            {
                DescriptionBox.Text += result;
                VoiceStatus.Text = "Done";
            }
            else
            {
                VoiceStatus.Text = "No speech detected";
            }
        }
        catch (Exception ex)
        {
            VoiceStatus.Text = $"Error: {ex.Message}";
        }
        finally
        {
            VoiceBtn.IsEnabled = true;
        }
    }

    private async void OpenSpeechSettings_Click(object sender, RoutedEventArgs e)
        => await Launcher.LaunchUriAsync(new Uri("ms-settings:privacy-speech"));

    // ── Image attachments ─────────────────────────────────────────────────

    private async void PasteImage_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var clipboard = Clipboard.GetContent();
            if (clipboard is null)
            {
                ImageStatus.Text = "Clipboard is empty.";
                return;
            }

            if (clipboard.Contains(StandardDataFormats.Bitmap))
            {
                var bitmapRef = await clipboard.GetBitmapAsync();
                using var stream = await bitmapRef.OpenReadAsync();

                // Read the bitmap stream into a byte array
                var bytes = await ReadStreamToBytes(stream);

                var name = $"clipboard-{DateTime.Now:HHmmss}.png";
                var attachment = new ImageAttachment(name, bytes, "image/png");
                _images.Add(attachment);
                RefreshImageList();
                ImageStatus.Text = $"Pasted image: {name}";
            }
            else if (clipboard.Contains(StandardDataFormats.StorageItems))
            {
                var items = await clipboard.GetStorageItemsAsync();
                int added = 0;
                foreach (var item in items)
                {
                    if (item is StorageFile file && IsImageFile(file.Name))
                    {
                        var bytes = await ReadFileToBytes(file);
                        var mime = MimeFromExtension(file.FileType);
                        _images.Add(new ImageAttachment(file.Name, bytes, mime));
                        added++;
                    }
                }
                if (added > 0)
                {
                    RefreshImageList();
                    ImageStatus.Text = $"Pasted {added} image(s) from clipboard.";
                }
                else
                {
                    ImageStatus.Text = "No images found on the clipboard.";
                }
            }
            else
            {
                ImageStatus.Text = "No image found on the clipboard. Copy an image first.";
            }
        }
        catch (Exception ex)
        {
            ImageStatus.Text = $"Paste failed: {ex.Message}";
        }
    }

    private async void BrowseImage_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var picker = new FileOpenPicker();
            picker.FileTypeFilter.Add(".png");
            picker.FileTypeFilter.Add(".jpg");
            picker.FileTypeFilter.Add(".jpeg");
            picker.FileTypeFilter.Add(".gif");
            picker.FileTypeFilter.Add(".webp");
            picker.FileTypeFilter.Add(".bmp");
            picker.SuggestedStartLocation = PickerLocationId.PicturesLibrary;

            // WinUI 3: must initialise picker with window handle
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow!);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

            var files = await picker.PickMultipleFilesAsync();
            if (files is null || files.Count == 0) return;

            foreach (var file in files)
            {
                var bytes = await ReadFileToBytes(file);
                var mime = MimeFromExtension(file.FileType);
                _images.Add(new ImageAttachment(file.Name, bytes, mime));
            }
            RefreshImageList();
            ImageStatus.Text = $"{files.Count} image(s) added.";
        }
        catch (Exception ex)
        {
            ImageStatus.Text = $"Browse failed: {ex.Message}";
        }
    }

    private void RemoveImage_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as Button)?.Tag is ImageAttachment img)
        {
            _images.Remove(img);
            RefreshImageList();
            ImageStatus.Text = _images.Count == 0 ? "" : $"{_images.Count} image(s) attached.";
        }
    }

    private void RefreshImageList()
    {
        ImageList.ItemsSource = null;
        ImageList.ItemsSource = _images;
        ImageList.Visibility = _images.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    // ── Submit ────────────────────────────────────────────────────────────

    private async void Submit_Click(object sender, RoutedEventArgs e)
    {
        var description = DescriptionBox.Text.Trim();
        if (string.IsNullOrEmpty(description))
        {
            ErrorText.Text = "Description is required.";
            return;
        }

        var taskType = (TypeBox.SelectedItem as ComboBoxItem)?.Tag as string ?? "research";
        var model = (ModelBox.SelectedItem as ComboBoxItem)?.Content as string ?? "claude-opus-4-6";
        var repoUrl = RepoUrlBox.Text.Trim();
        var baseBranch = BaseBranchBox.Text.Trim();
        var projectId = (ProjectBox.SelectedItem as ComboBoxItem)?.Tag as string;
        var deliveryMode = (DeliveryBox.SelectedItem as ComboBoxItem)?.Tag as string;

        if (taskType == "code" && string.IsNullOrEmpty(repoUrl))
        {
            ErrorText.Text = "Repository URL is required for code tasks.";
            return;
        }

        string? targetOs = null;
        string? difficulty = null;
        if (taskType == "instructions")
        {
            var osList = new List<string>();
            if (OsWindows.IsChecked == true) osList.Add("windows");
            if (OsMacOS.IsChecked == true) osList.Add("macos");
            if (OsLinux.IsChecked == true) osList.Add("linux");
            targetOs = osList.Count > 0 ? string.Join(",", osList) : "windows";
            difficulty = (DifficultyBox.SelectedItem as ComboBoxItem)?.Content as string ?? "Beginner";
        }

        ErrorText.Text = "";
        SubmitBtn.IsEnabled = false;
        Spinner.IsActive = true;

        try
        {
            var task = await _api.CreateTaskAsync(
                description,
                taskType,
                llmBackend: "anthropic",
                llmModel: model,
                repoUrl: taskType == "code" ? repoUrl : "",
                baseBranch: taskType == "code" && !string.IsNullOrEmpty(baseBranch) ? baseBranch : "main",
                projectId: projectId,
                targetOs: targetOs,
                difficulty: difficulty,
                deliveryMode: taskType is "research" or "deep_research" or "structured_document"
                    ? deliveryMode : null,
                images: _images.Count > 0 ? _images : null);

            Frame.Navigate(typeof(TaskDetailPage), task.Id);
        }
        catch (Exception ex)
        {
            ErrorText.Text = $"Failed to create task: {ex.Message}";
        }
        finally
        {
            SubmitBtn.IsEnabled = true;
            Spinner.IsActive = false;
        }
    }

    // ── Image helpers ─────────────────────────────────────────────────────

    private static bool IsImageFile(string name)
    {
        var ext = Path.GetExtension(name).ToLowerInvariant();
        return ext is ".png" or ".jpg" or ".jpeg" or ".gif" or ".webp" or ".bmp";
    }

    private static string MimeFromExtension(string ext)
    {
        return ext.ToLowerInvariant() switch
        {
            ".png"  => "image/png",
            ".jpg"  => "image/jpeg",
            ".jpeg" => "image/jpeg",
            ".gif"  => "image/gif",
            ".webp" => "image/webp",
            ".bmp"  => "image/bmp",
            _       => "application/octet-stream",
        };
    }

    private static async Task<byte[]> ReadStreamToBytes(IRandomAccessStreamWithContentType stream)
    {
        using var reader = new DataReader(stream);
        var bytes = new byte[stream.Size];
        await reader.LoadAsync((uint)stream.Size);
        reader.ReadBytes(bytes);
        return bytes;
    }

    private static async Task<byte[]> ReadFileToBytes(StorageFile file)
    {
        var buffer = await FileIO.ReadBufferAsync(file);
        using var reader = DataReader.FromBuffer(buffer);
        var bytes = new byte[buffer.Length];
        reader.ReadBytes(bytes);
        return bytes;
    }
}
