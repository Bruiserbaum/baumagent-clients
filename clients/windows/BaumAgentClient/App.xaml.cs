using BaumAgent.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;

namespace BaumAgent;

public partial class App : Application
{
    private static readonly string LogPath =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "BaumAgent", "crash.log");

    public static IServiceProvider Services { get; private set; } = null!;
    public static MainWindow? MainWindow { get; private set; }

    public App()
    {
        UnhandledException += (_, e) =>
        {
            e.Handled = true;
            Log("UnhandledException", e.Exception);
        };

        try
        {
            InitializeComponent();
        }
        catch (Exception ex) { Log("InitializeComponent", ex); throw; }

        var services = new ServiceCollection();
        ConfigureServices(services);
        Services = services.BuildServiceProvider();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            MainWindow = new MainWindow();
            MainWindow.Activate();
        }
        catch (Exception ex) { Log("OnLaunched", ex); throw; }
    }

    internal static void Log(string context, Exception ex)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);
            File.AppendAllText(LogPath,
                $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {context}: {ex}\n\n");
        }
        catch { }
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddSingleton<CredentialService>();
        services.AddSingleton<BaumAgentApiClient>();
        services.AddSingleton<WebSocketService>();
        services.AddSingleton<VoiceService>();
        services.AddSingleton<PushService>();
    }

    public static T GetService<T>() where T : class
        => Services.GetRequiredService<T>();
}
