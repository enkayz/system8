# Microsoft 365 operator gaps

System 8 does not aim to reproduce the Microsoft admin portals or another generic reporting dashboard. This wave focuses on the joins where operators still assemble evidence manually.

| Gap | Existing strength in the ecosystem | System 8 response |
|---|---|---|
| Licence reference versus tenant entitlement | [M365 Maps](https://m365maps.com/) makes product and feature inclusion understandable | `m365-entitlement-advisor` combines operator-owned capability requirements with live tenant service-plan assignments, without copying a matrix that will drift |
| Announcement volume versus operational consequence | Microsoft Message Center is authoritative but tenant impact and ownership still require interpretation | `m365-change-impact` joins Message Center and service health to live tenant scale and creates a prioritized action register |
| Copilot purchase versus trustworthy rollout | Microsoft documents licensing and SharePoint/Purview controls, while expert communities emphasize governance and practical administration | `m365-copilot-readiness` creates an explicit pilot gate and identifies evidence that generic Graph collection cannot prove |
| Access result versus access explanation | Portals expose memberships and assignments in separate views | `m365-access-explainer` joins nested membership, enterprise-app roles, ownership and licence evidence for one identity |
| Account disablement versus safe operational exit | Offboarding actions are easy to automate before dependencies are understood | `m365-leaver-readiness` inventories ownership, reporting and content dependencies and emits a non-destructive sequence |
| Security baseline versus recoverability | Baselines check controls, but lockout and expiring automation credentials are continuity risks | `m365-recovery-readiness` checks privileged redundancy, emergency-access signals, exclusions, domains and credential runway |

The operator style is informed by the practical Microsoft 365 work published by [Office 365 for IT Pros](https://office365itpros.com/), [CIAOPS / Robert Crane](https://github.com/directorcia/Office365), and service-focused Microsoft 365 practitioners such as [IT365](https://www.it365.ie/). These are references, not dependencies or copied implementations.

Primary implementation references:

- [Microsoft Graph service communications API](https://learn.microsoft.com/graph/api/resources/service-communications-api-overview)
- [Microsoft 365 licensing service-plan reference](https://learn.microsoft.com/entra/identity/users/licensing-service-plan-reference)
- [Prepare SharePoint for Microsoft 365 Copilot](https://learn.microsoft.com/microsoft-365/copilot/get-ready-copilot-sharepoint-advanced-management)
- [Microsoft Entra emergency access accounts](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)
- [Microsoft Graph transitive user membership](https://learn.microsoft.com/graph/api/user-list-transitivememberof)

All tools preserve source evidence, default to read-only operation, and state where a conclusion requires manual or licensed evidence outside generic Microsoft Graph.
