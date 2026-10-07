# Stack

Every third-party tool and service this product uses. Adding one is a blast-radius change: ADR plus a row here. Never put secrets here — say where they live (e.g. "Keychain: SERVICE_NAME"), not what they are.

| Category | Tool | Why this one | Account / identity | Config lives in | Cost |
|---|---|---|---|---|---|
| Work tracking | GitHub Issues | issues are the only work intake | | `.github/` | free |
| Web analytics | | | | | |
| Product analytics | | | | | |
| Error monitoring | | | | | |
| Email | | | | | |
| Payments | | | | | |
| Hosting | | | | | |
| Database | | | | | |
