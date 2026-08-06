using System.Text;
using System8Dashboard.Core.Models;

namespace System8Dashboard.Core.Services;

public sealed class AccessRequestService
{
    public AccessRequestDraft Create(ToolDefinition tool, ToolRunResult result, string requestDirectory, string? administratorEmail)
    {
        ArgumentNullException.ThrowIfNull(tool);
        ArgumentNullException.ThrowIfNull(result);
        Directory.CreateDirectory(requestDirectory);
        CollectionEvidence[] denied = result.Evidence.Where(item => item.IsDenied).ToArray();
        if (denied.Length == 0 && !result.IsSuccess)
        {
            denied = [new CollectionEvidence("Tool execution", "Failed", result.ExitCode, result.Error)];
        }
        string[] roles = SuggestRoles(denied).ToArray();
        string subject = $"System 8 access request: {tool.Name}";
        StringBuilder body = new();
        body.AppendLine("A read-only System 8 assessment encountered access limitations.");
        body.AppendLine();
        body.AppendLine($"Tool: {tool.Name}");
        body.AppendLine($"Requested by: {Environment.UserName}");
        body.AppendLine($"Generated: {DateTimeOffset.Now:O}");
        body.AppendLine($"Evidence folder: {result.OutputPath}");
        body.AppendLine();
        body.AppendLine("Denied collections:");
        foreach (CollectionEvidence item in denied) body.AppendLine($"- {item.Collection}: {Redact(item.Error)}");
        body.AppendLine();
        body.AppendLine($"Suggested least-privilege review roles: {string.Join(", ", roles)}");
        body.AppendLine("Please grant time-bound access through PIM where available, or reply with the approved alternative. No elevation bypass is requested.");
        string path = Path.Combine(requestDirectory, $"access-request-{DateTime.Now:yyyyMMdd-HHmmss}.md");
        File.WriteAllText(path, $"# {subject}{Environment.NewLine}{Environment.NewLine}{body}");
        string recipient = administratorEmail?.Trim() ?? string.Empty;
        string mailto = $"mailto:{Uri.EscapeDataString(recipient)}?subject={Uri.EscapeDataString(subject)}&body={Uri.EscapeDataString(body.ToString())}";
        return new AccessRequestDraft(subject, body.ToString(), mailto, path, roles);
    }

    public IReadOnlyList<string> SuggestRoles(IEnumerable<CollectionEvidence> deniedEvidence)
    {
        HashSet<string> roles = new(StringComparer.OrdinalIgnoreCase);
        foreach (CollectionEvidence item in deniedEvidence)
        {
            string value = $"{item.Collection} {item.Error}";
            if (value.Contains("Conditional Access", StringComparison.OrdinalIgnoreCase) || value.Contains("Policy.Read", StringComparison.OrdinalIgnoreCase)) roles.Add("Conditional Access Reader");
            if (value.Contains("Application", StringComparison.OrdinalIgnoreCase)) roles.Add("Directory Readers");
            if (value.Contains("Service health", StringComparison.OrdinalIgnoreCase) || value.Contains("Message Center", StringComparison.OrdinalIgnoreCase)) roles.Add("Service Support Administrator");
            if (value.Contains("SharePoint", StringComparison.OrdinalIgnoreCase) || value.Contains("Sites.Read", StringComparison.OrdinalIgnoreCase)) roles.Add("SharePoint Administrator");
            if (value.Contains("License", StringComparison.OrdinalIgnoreCase)) roles.Add("License Administrator");
        }

        if (roles.Count == 0) roles.Add("Directory Readers");
        return roles.OrderBy(value => value, StringComparer.CurrentCultureIgnoreCase).ToArray();
    }

    private static string Redact(string? error)
    {
        if (string.IsNullOrWhiteSpace(error)) return "Access denied; no detail returned.";
        string singleLine = error.ReplaceLineEndings(" ");
        return singleLine.Length <= 400 ? singleLine : string.Concat(singleLine.AsSpan(0, 400), "…");
    }
}
