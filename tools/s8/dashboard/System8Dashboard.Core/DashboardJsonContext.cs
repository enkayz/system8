using System.Text.Json.Serialization;
using System8Dashboard.Core.Models;

namespace System8Dashboard.Core;

[JsonSourceGenerationOptions(PropertyNameCaseInsensitive = true)]
[JsonSerializable(typeof(CollectionEvidence[]))]
[JsonSerializable(typeof(PimEligibilityResult))]
internal sealed partial class DashboardJsonContext : JsonSerializerContext
{
}
