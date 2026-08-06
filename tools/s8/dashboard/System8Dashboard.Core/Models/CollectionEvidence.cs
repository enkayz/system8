namespace System8Dashboard.Core.Models;

public sealed record CollectionEvidence(string Collection, string Status, int Records, string? Error)
{
    public bool IsDenied => Status.Equals("Failed", StringComparison.OrdinalIgnoreCase) &&
        (Error?.Contains("403", StringComparison.OrdinalIgnoreCase) == true ||
         Error?.Contains("Authorization", StringComparison.OrdinalIgnoreCase) == true ||
         Error?.Contains("privilege", StringComparison.OrdinalIgnoreCase) == true ||
         Error?.Contains("permission", StringComparison.OrdinalIgnoreCase) == true);
}
