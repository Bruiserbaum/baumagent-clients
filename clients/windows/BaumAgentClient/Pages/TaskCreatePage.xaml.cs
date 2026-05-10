using BaumAgent.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.System;

namespace BaumAgent.Pages;

public sealed partial class TaskCreatePage : Page
{
    private readonly BaumAgentApiClient _api = App.GetService<BaumAgentApiClient>();
    private readonly VoiceService _voice = App.GetService<VoiceService>();

    public TaskCreatePage()
    {
        InitializeComponent();
        TypeBox.SelectionChanged += TypeBox_SelectionChanged;
    }

    private void TypeBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var tag = (TypeBox.SelectedItem as ComboBoxItem)?.Tag as string;
        CodeOptions.Visibility = tag == "code" ? Visibility.Visible : Visibility.Collapsed;
        InstructionsOptions.Visibility = tag == "instructions" ? Visibility.Visible : Visibility.Collapsed;
        DescriptionBox.PlaceholderText = tag switch
        {
            "instructions" => "Describe the technology or process to write step-by-step instructions for…",
            "code"         => "Describe what the agent should do in the repository…",
            _              => "Describe the task…",
        };
    }

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
                targetOs: targetOs,
                difficulty: difficulty);

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
}
