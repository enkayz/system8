using System.Diagnostics;
using System8Dashboard.Core.Models;

namespace System8Dashboard.Core.Tests;

[TestClass]
public sealed class PimEligibilityResultTests
{
    [TestMethod]
    public void HasMatch_WhenStatusIsFoundAndRoleExists_ReturnsTrue()
    {
        PimEligibilityResult result = new("Found", ["Directory Readers"], "Found");

        Assert.IsTrue(result.HasMatch);
    }

    [TestMethod]
    public void HasMatch_WhenStatusIsUnknown_ReturnsFalse()
    {
        PimEligibilityResult result = new("Unknown", ["Directory Readers"], "Unknown");

        Assert.IsFalse(result.HasMatch);
    }

    [TestMethod]
    public async Task CheckAsync_WhenHelperReturnsJson_ParsesEligibility()
    {
        string script = Path.Combine(Path.GetTempPath(), $"system8-pim-{Guid.NewGuid():N}.ps1");
        try
        {
            await File.WriteAllTextAsync(script, "param([string[]]$SuggestedRole); [pscustomobject]@{Status='Found';EligibleRoles=@('Directory Readers');Message='Found'}|ConvertTo-Json -Compress");

            PimEligibilityResult result = await new System8Dashboard.Core.Services.PimEligibilityService(CreateTestStartInfo)
                .CheckAsync(script, ["Directory Readers"]);

            Assert.IsTrue(result.HasMatch);
        }
        finally
        {
            if (File.Exists(script)) File.Delete(script);
        }
    }

    private static ProcessStartInfo CreateTestStartInfo(string scriptPath, IEnumerable<string> arguments)
    {
        ProcessStartInfo startInfo = new("powershell.exe")
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        foreach (string argument in new[] { "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath }.Concat(arguments))
        {
            startInfo.ArgumentList.Add(argument);
        }
        return startInfo;
    }
}
