using System8Dashboard.Core.Models;
using System8Dashboard.Core.Services;

namespace System8Dashboard.Core.Tests.Services;

[TestClass]
public sealed class AccessRequestServiceTests
{
    [TestMethod]
    public void SuggestRoles_ConditionalAccessFailure_ReturnsConditionalAccessReader()
    {
        AccessRequestService service = new();
        CollectionEvidence[] evidence = [new("Conditional Access policies", "Failed", 0, "403 Policy.Read.All permission required")];

        IReadOnlyList<string> result = service.SuggestRoles(evidence);

        CollectionAssert.Contains(result.ToList(), "Conditional Access Reader");
    }

    [TestMethod]
    public void SuggestRoles_UnknownFailure_ReturnsDirectoryReaders()
    {
        AccessRequestService service = new();
        CollectionEvidence[] evidence = [new("Unknown", "Failed", 0, "Authorization denied")];

        IReadOnlyList<string> result = service.SuggestRoles(evidence);

        CollectionAssert.AreEqual(new[] { "Directory Readers" }, result.ToArray());
    }
}
