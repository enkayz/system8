using System8Dashboard.Core.Models;
using System8Dashboard.Core.Services;

namespace System8Dashboard.Core.Tests;

[TestClass]
public sealed class ToolServicesTests
{
    [TestMethod]
    public void Discover_WhenManifestIsMissing_ReturnsKnownOperatorTools()
    {
        string missingManifest = Path.Combine(Path.GetTempPath(), $"missing-{Guid.NewGuid():N}.json");
        string emptyUserRoot = Path.Combine(Path.GetTempPath(), $"system8-empty-{Guid.NewGuid():N}");

        IReadOnlyList<ToolDefinition> tools = new ToolCatalogService(emptyUserRoot).Discover(missingManifest);

        Assert.IsGreaterThanOrEqualTo(13, tools.Count);
        Assert.IsTrue(tools.Any(tool => tool.Name == "m365-security-baseline"));
        Assert.IsFalse(tools.Any(tool => tool.IsInstalled));
    }

    [TestMethod]
    public async Task RunAsync_WhenPackageIsMissing_ThrowsFileNotFoundException()
    {
        ToolDefinition tool = new("missing", "missing", "Missing", null, false);

        await Assert.ThrowsExactlyAsync<FileNotFoundException>(() =>
            new ToolRunnerService().RunAsync(tool, [], Path.GetTempPath()));
    }

    [TestMethod]
    public async Task InstallAsync_WhenPackageNameContainsShellCharacters_RejectsInput()
    {
        await Assert.ThrowsExactlyAsync<ArgumentException>(() =>
            new UserPackageInstallerService().InstallAsync("m365;whoami", "missing.ps1"));
    }
}
