# Governance

## Change ownership

- Product behavior and code changes are reviewed in `farabek/agripartners`.
- Funding narrative changes are reviewed in
  `farabek/agripartners-funding-package`.
- Operational and relationship changes are reviewed privately in
  `farabek/agripartners-hq`.
- Cross-repository boundary changes update this repository and every affected
  repository pointer in the same change set.

## Public/private boundary

Public repositories may contain information intended for users, developers,
auditors, funders, and partners. Personal data, non-public communications,
credentials, active outreach pipelines, and internal assessments belong only
in approved private systems.

## Consistency checks

Before completing a cross-repository change:

1. Confirm the artifact has one canonical owner.
2. Replace stale duplicates with links or ownership notices.
3. Verify public links and access permissions.
4. Run the tests and checks owned by each changed repository.
5. Confirm production build metadata when product deployment is affected.

The canonical automated check is
[`scripts/audit-ecosystem.ps1`](scripts/audit-ecosystem.ps1). Run it locally
after cross-repository changes. Its public CI mode runs daily and must remain
free of credentials or private-repository dependencies.
