# AgriPartners Ecosystem

Public map of the AgriPartners project: repository ownership, system boundaries,
governance, and security reporting.

## Canonical repositories

| Repository | Visibility | Responsibility |
| --- | --- | --- |
| [`farabek/agripartners`](https://github.com/farabek/agripartners) | Public | Product source code, contracts, application documentation, tests, and deployment configuration |
| [`farabek/agripartners-funding-package`](https://github.com/farabek/agripartners-funding-package) | Public | Grant- and funding-facing materials intended for external review |
| `farabek/agripartners-hq` | Private | Internal operations, relationship CRM, outreach, decisions, and working pipelines |
| [`farabek/agripartners-ecosystem`](https://github.com/farabek/agripartners-ecosystem) | Public | This repository: cross-repository map, governance, architecture boundaries, and security contacts |

`farabek/near-project` is not a canonical AgriPartners repository. It belongs to
a separate NEAR Edu-Arbitrage project.

## Start here

- [Choose where to go by role or task](START_HERE.md)
- [Repository map](REPOSITORY_MAP.md)
- [Governance](GOVERNANCE.md)
- [Architecture](ARCHITECTURE.md)
- [Security policy](SECURITY.md)

## Consistency audit

Run the complete local audit from this repository:

```powershell
.\scripts\audit-ecosystem.ps1 -Mode Local
```

It verifies all four canonical local clones, their remotes and clean `main`
branches, repository ownership markers, public GitHub state, production commit,
navigation links, and forbidden private/secret paths. The scheduled
[Ecosystem audit workflow](.github/workflows/ecosystem-audit.yml) checks the
public repositories and Vercel every day; private HQ remains a local-only check
unless a dedicated read-only secret is explicitly configured.

This repository intentionally contains no credentials, personal contact data,
private CRM records, outreach pipelines, or duplicated product/funding content.
