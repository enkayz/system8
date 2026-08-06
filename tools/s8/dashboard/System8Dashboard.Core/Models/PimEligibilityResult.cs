namespace System8Dashboard.Core.Models;

public sealed record PimEligibilityResult(string Status, IReadOnlyList<string> EligibleRoles, string Message)
{
    public bool HasMatch => Status.Equals("Found", StringComparison.OrdinalIgnoreCase) && EligibleRoles.Count > 0;
}
