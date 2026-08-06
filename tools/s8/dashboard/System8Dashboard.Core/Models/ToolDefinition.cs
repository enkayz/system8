namespace System8Dashboard.Core.Models;

public sealed record ToolDefinition(string Name, string Command, string Description, string? ScriptPath, bool IsInstalled)
{
    public string Availability => IsInstalled ? "Ready" : "Not installed";
}
