using System.Diagnostics;

namespace System8Dashboard.Core.Services;

public sealed class UserPackageInstallerService
{
    public async Task<string> InstallAsync(string packageName, string installerPath, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(packageName) || packageName.Any(character => !(char.IsLetterOrDigit(character) || character == '-'))) throw new ArgumentException("Package name contains unsupported characters.", nameof(packageName));
        if (!File.Exists(installerPath)) throw new FileNotFoundException("The per-user installer is unavailable.", installerPath);
        ProcessStartInfo startInfo = ToolchainService.CreatePowerShellStartInfo(installerPath, ["install", packageName]);
        using Process process = new() { StartInfo = startInfo };
        process.Start();
        Task<string> outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        Task<string> errorTask = process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
        string output = await outputTask.ConfigureAwait(false);
        string error = await errorTask.ConfigureAwait(false);
        if (process.ExitCode != 0) throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? output : error);
        return output;
    }
}
