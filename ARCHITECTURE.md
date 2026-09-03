# Architecture Boundaries

```text
agripartners-ecosystem (public map and governance)
             |
             +--> agripartners (public product) --> Vercel production
             |
             +--> agripartners-funding-package (public funding materials)
             |
             +--> agripartners-hq (private operations and CRM)
```

The ecosystem repository defines boundaries but does not mirror the contents
of the other repositories. The product repository owns executable behavior and
deployment configuration. The funding package owns externally reviewable
funding narratives. HQ owns non-public operational state.

Changes should flow through links and explicit ownership records, not copied
documents. This prevents public/private leakage and conflicting versions.

