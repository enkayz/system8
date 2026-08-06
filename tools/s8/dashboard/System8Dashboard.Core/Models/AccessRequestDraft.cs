namespace System8Dashboard.Core.Models;

public sealed record AccessRequestDraft(string Subject, string Body, string MailtoUri, string RequestPath, IReadOnlyList<string> SuggestedRoles);
