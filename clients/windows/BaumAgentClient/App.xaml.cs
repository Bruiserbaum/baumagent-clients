using BaumAgent.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;

namespace BaumAgent;

public partial class App : Application
{
    public static IServiceProvider Services { get; private set; } = null!;
    public static MainWindow? MainWindow { get; private set; }

    public App()
    {
        InitializeComponent();

        var services = new ServiceCollection();
        ConfigureServices(services);
        Services = services.BuildServiceProvider();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        MainWindow = new MainWindow();
        MainWindow.Activate();
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
