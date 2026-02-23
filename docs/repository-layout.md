# Repository Layout

```text
.
├── specs/
│   ├── catalog.json
│   ├── api-clients/
│   ├── iam/
│   ├── programmable-wireless/
│   ├── supersim/
│   └── webhook/
├── docs/
│   ├── generating-sdks.md
│   ├── prerequisites.md
│   └── repository-layout.md
├── scripts/                          # internal implementation for make targets
├── Makefile                          # primary user entrypoint
└── LICENSE
```

## Conventions

- `specs/catalog.json` is the source of truth for available spec IDs.
- Catalog entries may also include portal/auth metadata (for example `portal`, `token_url`, `docs_url`) used by tooling.
- Prefer `make` targets over invoking scripts directly.
- Generated SDKs are written to `generated/` and are not committed by default.
