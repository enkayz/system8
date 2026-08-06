using System.Diagnostics;

namespace System8Dashboard.Core.Services;

public static class ToolchainService
{
    public const string GraphModuleVersion = "2.38.1";
    public const string PowerShellVersion = "7.6.4";

    public static string RootPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "System8",
        "Toolchain");

    public static ProcessStartInfo CreatePowerShellStartInfo(string scriptPath, IEnumerable<string> scriptArguments)
    {
        string executablePath = Path.Combine(RootPath, "PowerShell", "pwsh.exe");
        string wrapperPath = Path.Combine(RootPath, "invoke-isolated.ps1");
        string graphModulePath = Path.Combine(RootPath, "Modules");
        string powerShellModulePath = Path.Combine(RootPath, "PowerShell", "Modules");
        string authenticationManifest = Path.Combine(graphModulePath, "Microsoft.Graph.Authentication", GraphModuleVersion, "Microsoft.Graph.Authentication.psd1");
        if (!File.Exists(executablePath) || !File.Exists(wrapperPath) || !File.Exists(authenticationManifest))
        {
            throw new InvalidOperationException("The isolated System 8 toolchain is missing or incomplete. Re-run the dashboard installer to restore it.");
        }

        ProcessStartInfo startInfo = new(executablePath)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        startInfo.Environment["PSModulePath"] = string.Join(Path.PathSeparator, graphModulePath, powerShellModulePath);
        startInfo.Environment["S8_TOOLCHAIN_ROOT"] = RootPath;
        startInfo.Environment["S8_TARGET_SCRIPT"] = Path.GetFullPath(scriptPath);
        startInfo.Environment["POWERSHELL_TELEMETRY_OPTOUT"] = "1";
        startInfo.Environment["POWERSHELL_UPDATECHECK"] = "Off";
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(wrapperPath);
        foreach (string argument in scriptArguments) startInfo.ArgumentList.Add(argument);
        return startInfo;
    }
}
