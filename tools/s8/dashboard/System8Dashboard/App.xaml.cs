using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using System8Dashboard.Core.Services;
using System8Dashboard.ViewModels;

namespace System8Dashboard;

public partial class App : Application
{
    private Window? _window;
    private static readonly string StartupLogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "System8",
        "dashboard",
        "startup.log");

    public App()
    {
        UnhandledException += (_, args) => WriteStartupLog("Unhandled", args.Exception);
        WriteStartupLog("Application construction started");
        InitializeComponent();
        WriteStartupLog("Application resources loaded");
        ServiceCollection services = new();
        services.AddSingleton<ToolCatalogService>();
        services.AddSingleton<ToolRunnerService>();
        services.AddSingleton<AccessRequestService>();
        services.AddSingleton<PimEligibilityService>();
        services.AddSingleton<UserPackageInstallerService>();
        services.AddSingleton<MainViewModel>();
        Services = services.BuildServiceProvider();
        WriteStartupLog("Services configured");
    }

    public static IServiceProvider Services { get; private set; } = null!;

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            WriteStartupLog("Window construction started");
            _window = new MainWindow(Services.GetRequiredService<MainViewModel>(), Services.GetRequiredService<PimEligibilityService>());
            WriteStartupLog("Window construction completed");
            _window.Activate();
            WriteStartupLog("Window activated");
        }
        catch (Exception exception)
        {
            WriteStartupLog("Launch failed", exception);
            throw;
        }
    }

    private static void WriteStartupLog(string message, Exception? exception = null)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(StartupLogPath)!);
            string detail = exception is null ? string.Empty : $" | {exception}";
            File.AppendAllText(StartupLogPath, $"{DateTimeOffset.Now:O} {message}{detail}{Environment.NewLine}");
        }
        catch
        {
        }
    }
}
