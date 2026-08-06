using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.Windows.ApplicationModel.Resources;
using System8Dashboard.Core.Models;
using System8Dashboard.Core.Services;

namespace System8Dashboard.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly AccessRequestService _accessRequestService;
    private readonly ToolCatalogService _catalogService;
    private readonly ToolRunnerService _runnerService;
    private readonly UserPackageInstallerService _installerService;
    private readonly ResourceLoader _resources = new();

    [ObservableProperty]
    public partial string AccessRequestBody { get; set; }

    [ObservableProperty]
    public partial string AdministratorEmail { get; set; }

    [ObservableProperty]
    public partial string Arguments { get; set; }

    [ObservableProperty]
    public partial bool HasAccessGaps { get; set; }

    [ObservableProperty]
    public partial bool IsBusy { get; set; }

    [ObservableProperty]
    public partial string ResultText { get; set; }

    [ObservableProperty]
    public partial ToolDefinition? SelectedTool { get; set; }

    [ObservableProperty]
    public partial string Status { get; set; }

    public MainViewModel(ToolCatalogService catalogService, ToolRunnerService runnerService, AccessRequestService accessRequestService, UserPackageInstallerService installerService)
    {
        _catalogService = catalogService;
        _runnerService = runnerService;
        _accessRequestService = accessRequestService;
        _installerService = installerService;
        AccessRequestBody = string.Empty;
        AdministratorEmail = string.Empty;
        Arguments = "doctor";
        ResultText = string.Empty;
        Status = Text("StatusReady");
    }

    public ObservableCollection<CollectionEvidence> Evidence { get; } = [];

    public ObservableCollection<ToolDefinition> Tools { get; } = [];

    public string ToolchainPath => ToolchainService.RootPath;

    public string ToolchainSummary => string.Format(
        System.Globalization.CultureInfo.CurrentCulture,
        Text("ToolchainReadyFormat"),
        ToolchainService.PowerShellVersion,
        ToolchainService.GraphModuleVersion);

    public ToolRunResult? LastRun { get; private set; }

    public void Refresh()
    {
        Tools.Clear();
        foreach (ToolDefinition tool in _catalogService.Discover()) Tools.Add(tool);
        SelectedTool ??= Tools.FirstOrDefault();
        Status = string.Format(System.Globalization.CultureInfo.CurrentCulture, Text("StatusToolsFoundFormat"), Tools.Count);
    }

    public async Task RunSelectedAsync(CancellationToken cancellationToken = default)
    {
        if (SelectedTool is null)
        {
            Status = Text("StatusChooseTool");
            return;
        }

        IsBusy = true;
        HasAccessGaps = false;
        Evidence.Clear();
        string outputPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "System 8", "Evidence", $"{SelectedTool.Name}-{DateTime.Now:yyyyMMdd-HHmmss}");
        try
        {
            LastRun = await _runnerService.RunAsync(SelectedTool, ParseArguments(Arguments), outputPath, cancellationToken);
            foreach (CollectionEvidence item in LastRun.Evidence) Evidence.Add(item);
            HasAccessGaps = LastRun.HasAccessGaps || (!LastRun.IsSuccess && ContainsAccessError(LastRun.Error));
            ResultText = string.IsNullOrWhiteSpace(LastRun.Output) ? LastRun.Error : LastRun.Output;
            Status = LastRun.IsSuccess
                ? string.Format(System.Globalization.CultureInfo.CurrentCulture, Text("StatusCompletedFormat"), outputPath)
                : string.Format(System.Globalization.CultureInfo.CurrentCulture, Text("StatusExitCodeFormat"), LastRun.ExitCode);
        }
        catch (Exception exception) when (exception is IOException or InvalidOperationException)
        {
            ResultText = exception.Message;
            Status = Text("StatusRunFailed");
        }
        finally
        {
            IsBusy = false;
        }
    }

    public AccessRequestDraft? CreateAccessRequest()
    {
        if (SelectedTool is null || LastRun is null)
        {
            Status = Text("StatusRequestRunFirst");
            return null;
        }

        string requests = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "System 8", "Requests");
        AccessRequestDraft draft = _accessRequestService.Create(SelectedTool, LastRun, requests, AdministratorEmail);
        AccessRequestBody = draft.Body;
        Status = string.Format(System.Globalization.CultureInfo.CurrentCulture, Text("StatusRequestPreparedFormat"), draft.RequestPath);
        return draft;
    }

    public async Task InstallSelectedAsync(string installerPath, CancellationToken cancellationToken = default)
    {
        if (SelectedTool is null) { Status = Text("StatusChooseTool"); return; }
        IsBusy = true;
        try
        {
            ResultText = await _installerService.InstallAsync(SelectedTool.Name, installerPath, cancellationToken);
            SelectedTool = null;
            Refresh();
            Status = Text("StatusInstalled");
        }
        catch (Exception exception) when (exception is IOException or InvalidOperationException or ArgumentException)
        {
            ResultText = exception.Message;
            Status = Text("StatusInstallFailed");
        }
        finally { IsBusy = false; }
    }

    partial void OnSelectedToolChanged(ToolDefinition? value)
    {
        if (LastRun is null) return;
        LastRun = null;
        HasAccessGaps = false;
        Evidence.Clear();
        AccessRequestBody = string.Empty;
        ResultText = string.Empty;
        Status = Text("StatusReady");
    }

    private static bool ContainsAccessError(string error) => error.Contains("Authorization", StringComparison.OrdinalIgnoreCase) || error.Contains("permission", StringComparison.OrdinalIgnoreCase) || error.Contains("403", StringComparison.OrdinalIgnoreCase);

    private string Text(string key) => _resources.GetString(key);

    private static IReadOnlyList<string> ParseArguments(string value)
    {
        List<string> result = [];
        bool quoted = false;
        System.Text.StringBuilder current = new();
        foreach (char character in value)
        {
            if (character == '"') { quoted = !quoted; continue; }
            if (char.IsWhiteSpace(character) && !quoted)
            {
                if (current.Length > 0) { result.Add(current.ToString()); current.Clear(); }
            }
            else current.Append(character);
        }

        if (current.Length > 0) result.Add(current.ToString());
        return result;
    }
}
