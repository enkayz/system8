using System.Diagnostics;
using System.Text.Json;
using System8Dashboard.Core.Models;

namespace System8Dashboard.Core.Services;

public sealed class ToolRunnerService
{
    public async Task<ToolRunResult> RunAsync(ToolDefinition tool, IEnumerable<string> arguments, string outputPath, CancellationToken cancellationToken = default)
    {
        if (!tool.IsInstalled || string.IsNullOrWhiteSpace(tool.ScriptPath) || !File.Exists(tool.ScriptPath))
        {
            throw new FileNotFoundException("The selected System 8 package is not installed for this user.", tool.ScriptPath);
        }

        Directory.CreateDirectory(outputPath);
        List<string> scriptArguments = [.. arguments.Where(value => !string.IsNullOrWhiteSpace(value)), "-OutputPath", Path.GetFullPath(outputPath)];
        ProcessStartInfo startInfo = ToolchainService.CreatePowerShellStartInfo(tool.ScriptPath, scriptArguments);

        using Process process = new() { StartInfo = startInfo };
        process.Start();
        Task<string> outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        Task<string> errorTask = process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
        string output = await outputTask.ConfigureAwait(false);
        string error = await errorTask.ConfigureAwait(false);
        return new ToolRunResult(process.ExitCode, output, error, outputPath, ReadEvidence(outputPath));
    }

    private static IReadOnlyList<CollectionEvidence> ReadEvidence(string outputPath)
    {
        string path = Path.Combine(outputPath, "collection-evidence.json");
        if (!File.Exists(path)) return [];
        try
        {
            return JsonSerializer.Deserialize(File.ReadAllText(path), DashboardJsonContext.Default.CollectionEvidenceArray) ?? [];
        }
        catch (JsonException)
        {
            return [new CollectionEvidence("Evidence file", "Failed", 0, "The evidence JSON could not be parsed.")];
        }
    }

}
