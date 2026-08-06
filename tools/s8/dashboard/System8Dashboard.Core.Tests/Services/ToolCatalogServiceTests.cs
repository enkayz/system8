using System8Dashboard.Core.Services;

namespace System8Dashboard.Core.Tests.Services;

[TestClass]
public sealed class ToolCatalogServiceTests
{
    [TestMethod]
    public void Discover_BundledSourceExists_RequiresCurrentUserInstallation()
    {
        string testRoot = Path.Combine(Path.GetTempPath(), $"system8-catalog-{Guid.NewGuid():N}");
        string installedRoot = Path.Combine(testRoot, "installed");
        string bundledPackage = Path.Combine(testRoot, "packages", "m365-security-baseline");
        Directory.CreateDirectory(bundledPackage);
        File.WriteAllText(Path.Combine(bundledPackage, "security-baseline.ps1"), "Write-Output 'bundled'");
        string manifestPath = Path.Combine(testRoot, "stable.json");
        File.WriteAllText(manifestPath, """
            { "packages": [ { "name": "m365-security-baseline", "description": "Security baseline" } ] }
            """);
        ToolCatalogService service = new(installedRoot);

        IReadOnlyList<System8Dashboard.Core.Models.ToolDefinition> beforeInstall = service.Discover(manifestPath);
        Directory.CreateDirectory(Path.Combine(installedRoot, "m365-security-baseline"));
        File.WriteAllText(Path.Combine(installedRoot, "m365-security-baseline", "security-baseline.ps1"), "Write-Output 'installed'");
        IReadOnlyList<System8Dashboard.Core.Models.ToolDefinition> afterInstall = service.Discover(manifestPath);

        Assert.IsFalse(beforeInstall.Single().IsInstalled);
        Assert.IsTrue(afterInstall.Single().IsInstalled);
        Assert.IsNotNull(afterInstall.Single().ScriptPath);
        StringAssert.Contains(afterInstall.Single().ScriptPath!, installedRoot);

        Directory.Delete(testRoot, recursive: true);
    }
}
