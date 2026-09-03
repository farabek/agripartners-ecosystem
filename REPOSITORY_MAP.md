# Repository Map

## Source of truth

Each artifact has exactly one canonical home:

| Artifact | Canonical repository |
| --- | --- |
| Application and smart-contract code | `farabek/agripartners` |
| Product technical documentation | `farabek/agripartners` |
| Deployment and verification automation | `farabek/agripartners` |
| Public grant and funding package | `farabek/agripartners-funding-package` |
| Internal CRM and relationship history | `farabek/agripartners-hq` |
| Outreach templates and active pipelines | `farabek/agripartners-hq` |
| Internal decisions and operating records | `farabek/agripartners-hq` |
| Cross-repository boundaries and public governance | `farabek/agripartners-ecosystem` |

## Duplication rule

Do not maintain editable copies of the same artifact in multiple repositories.
Use a short pointer to its canonical location. Public repositories must not link
to private files as if external readers could access them; describe the owner
and access boundary instead.

## Deployment relationship

The production application at <https://agripartners.vercel.app> is deployed
from `farabek/agripartners`. A deployment is considered aligned only when its
published build metadata matches a commit in that repository and its smoke
checks pass.

