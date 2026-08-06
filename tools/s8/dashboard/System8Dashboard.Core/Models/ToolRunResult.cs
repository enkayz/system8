namespace System8Dashboard.Core.Models;

public sealed record ToolRunResult(int ExitCode, string Output, string Error, string OutputPath, IReadOnlyList<CollectionEvidence> Evidence)
{
    public bool IsSuccess => ExitCode == 0;
    public bool HasAccessGaps => Evidence.Any(item => item.IsDenied);
}
