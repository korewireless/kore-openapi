# Prerequisites

Use this checklist before running repository commands.

## Required

- `make`
- `bash`
- `jq`
- `curl` (used by `make smoke`)

## OpenAPI Generator Runtime (choose one)

- Docker (recommended), or
- local `openapi-generator-cli`, or
- Node.js + `npx` (used with `@openapitools/openapi-generator-cli`)

## Quick Verification

```bash
make check-prereqs
```

## Notes

- Docker and `npx` flows may download images/packages the first time they run.
- SDK generation output is written to `generated/` (ignored by git).
