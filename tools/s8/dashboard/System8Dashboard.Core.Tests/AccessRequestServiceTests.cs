using System8Dashboard.Core.Models;
using System8Dashboard.Core.Services;

namespace System8Dashboard.Core.Tests;

[TestClass]
public sealed class AccessRequestServiceTests
{
    [TestMethod]
    public void Create_WhenConditionalAccessIsDenied_SuggestsReaderAndWritesDraft()
    {
        string directory = Path.Combine(Path.GetTempPath(), $"system8-tests-{Guid.NewGuid():N}");
        try
        {
            ToolDefinition tool = new("m365-security-baseline", "s8secure", "Security", null, false);
            ToolRunResult run = new(1, string.Empty, string.Empty, directory,
                [new CollectionEvidence("Conditional Access policies", "Failed", 0, "403 Authorization_RequestDenied")]);

            AccessRequestDraft draft = new AccessRequestService().Create(tool, run, directory, null);

            CollectionAssert.Contains(draft.SuggestedRoles.ToArray(), "Conditional Access Reader");
            Assert.IsTrue(File.Exists(draft.RequestPath));
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }

    [TestMethod]
    public void Create_WhenToolFailsWithoutCollectionEvidence_UsesFallbackEvidence()
    {
        string directory = Path.Combine(Path.GetTempPath(), $"system8-tests-{Guid.NewGuid():N}");
        try
        {
            ToolDefinition tool = new("m365", "s8m365", "Inventory", null, false);
            ToolRunResult run = new(1, string.Empty, "permission denied", directory, []);

            AccessRequestDraft draft = new AccessRequestService().Create(tool, run, directory, null);

            CollectionAssert.Contains(draft.SuggestedRoles.ToArray(), "Directory Readers");
            StringAssert.Contains(draft.Body, "Tool execution");
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }
}
