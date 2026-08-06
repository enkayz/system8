using System.Text.Json;
using System8Dashboard.Core.Models;

namespace System8Dashboard.Core.Services;

public sealed class ToolCatalogService
{
    private readonly string _installedRoot;

    private static readonly Dictionary<string, string> CommandMap = new(StringComparer.OrdinalIgnoreCase)
    {
        ["m365"] = "s8m365", ["m365-governance"] = "s8gov", ["m365-license-optimizer"] = "s8license",
        ["m365-tenant-diff"] = "s8tenantdiff", ["m365-sharepoint-modernizer"] = "s8spmodern",
        ["m365-security-baseline"] = "s8secure", ["m365-migration-estimator"] = "s8migrate",
        ["m365-entitlement-advisor"] = "s8entitlement", ["m365-change-impact"] = "s8changes",
        ["m365-copilot-readiness"] = "s8copilot", ["m365-access-explainer"] = "s8access",
        ["m365-leaver-readiness"] = "s8leaver", ["m365-recovery-readiness"] = "s8resilience",
    };

    public ToolCatalogService()
        : this(null)
    {
    }

    public ToolCatalogService(string? installedRoot)
    {
        _installedRoot = installedRoot ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "System8",
            "Packages");
    }

    public IReadOnlyList<ToolDefinition> Discover(string? manifestPath = null)
    {
        string? resolvedManifest = manifestPath ?? FindManifest();
        if (resolvedManifest is null || !File.Exists(resolvedManifest))
        {
            return CommandMap.Select(item => CreateDefinition(item.Key, item.Value, "System 8 operator package")).ToArray();
        }

        using JsonDocument document = JsonDocument.Parse(File.ReadAllText(resolvedManifest));
        List<ToolDefinition> tools = [];
        foreach (JsonElement package in document.RootElement.GetProperty("packages").EnumerateArray())
        {
            string name = package.GetProperty("name").GetString() ?? string.Empty;
            if (!CommandMap.TryGetValue(name, out string? command))
            {
                continue;
            }

            string description = package.GetProperty("description").GetString() ?? string.Empty;
            string? script = FindInstalledScript(name);
            tools.Add(new ToolDefinition(name, command, description, script, script is not null));
        }

        return tools.OrderBy(item => item.Name, StringComparer.CurrentCultureIgnoreCase).ToArray();
    }

    private static string? FindManifest()
    {
        string bundledManifest = Path.Combine(AppContext.BaseDirectory, "Packages", "stable.json");
        if (File.Exists(bundledManifest)) return bundledManifest;

        DirectoryInfo? current = new(AppContext.BaseDirectory);
        while (current is not null)
        {
            string candidate = Path.Combine(current.FullName, "tools", "s8", "manifests", "stable.json");
            if (File.Exists(candidate)) return candidate;
            current = current.Parent;
        }

        return null;
    }

    private ToolDefinition CreateDefinition(string name, string command, string description)
    {
        string? script = FindInstalledScript(name);
        return new ToolDefinition(name, command, description, script, script is not null);
    }

    private string? FindInstalledScript(string packageName)
    {
        string directory = Path.Combine(_installedRoot, packageName);
        return Directory.Exists(directory)
            ? Directory.EnumerateFiles(directory, "*.ps1").FirstOrDefault(path =>
                !path.EndsWith("install.ps1", StringComparison.OrdinalIgnoreCase) &&
                !path.EndsWith("uninstall.ps1", StringComparison.OrdinalIgnoreCase))
            : null;
    }
}
