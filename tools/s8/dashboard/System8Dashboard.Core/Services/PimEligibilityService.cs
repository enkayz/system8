using System.Diagnostics;
using System8Dashboard.Core.Models;

namespace System8Dashboard.Core.Services;

public sealed class PimEligibilityService
{
    private readonly Func<string, IEnumerable<string>, ProcessStartInfo> _startInfoFactory;

    public PimEligibilityService()
        : this(ToolchainService.CreatePowerShellStartInfo)
    {
    }

    public PimEligibilityService(Func<string, IEnumerable<string>, ProcessStartInfo> startInfoFactory)
    {
        _startInfoFactory = startInfoFactory;
    }

    public async Task<PimEligibilityResult> CheckAsync(string scriptPath, IEnumerable<string> suggestedRoles, CancellationToken cancellationToken = default)
    {
        if (!File.Exists(scriptPath)) return new PimEligibilityResult("Unknown", [], "The PIM discovery helper is unavailable.");

        ProcessStartInfo startInfo;
        try
        {
            List<string> arguments = ["-SuggestedRole", .. suggestedRoles.Where(value => !string.IsNullOrWhiteSpace(value))];
            startInfo = _startInfoFactory(scriptPath, arguments);
        }
        catch (InvalidOperationException exception)
        {
            return new PimEligibilityResult("Unknown", [], Redact(exception.Message));
        }
        using Process process = new() { StartInfo = startInfo };
        process.Start();
        Task<string> outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        Task<string> errorTask = process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
        string output = await outputTask.ConfigureAwait(false);
        string error = await errorTask.ConfigureAwait(false);
        if (process.ExitCode != 0) return new PimEligibilityResult("Unknown", [], Redact(error));

        string json = output.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries).LastOrDefault() ?? string.Empty;
        try
        {
            return System.Text.Json.JsonSerializer.Deserialize(json, DashboardJsonContext.Default.PimEligibilityResult)
                ?? new PimEligibilityResult("Unknown", [], "PIM returned no result.");
        }
        catch (System.Text.Json.JsonException)
        {
            return new PimEligibilityResult("Unknown", [], "The PIM discovery response could not be read.");
        }
    }

    private static string Redact(string value)
    {
        string singleLine = string.IsNullOrWhiteSpace(value) ? "PIM eligibility could not be determined." : value.ReplaceLineEndings(" ");
        return singleLine.Length <= 400 ? singleLine : string.Concat(singleLine.AsSpan(0, 400), "…");
    }
}
