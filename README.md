# KORE OpenAPI

OpenAPI specifications for KORE public APIs, with a standardized repository layout and a simple `make`-based workflow for SDK generation.

## Quick Start

```bash
# validate local tooling
make check-prereqs

# list available spec IDs and source files
make specs

# run API smoke checks for all cataloged specs
make smoke

# generate one SDK
make generate-sdk SPEC=supersim-v1 GENERATOR=typescript-fetch

# generate the same SDK type for all specs
make generate-sdk-all GENERATOR=typescript-fetch
```

## Documentation

- Prerequisites: `docs/prerequisites.md`
- SDK generation guide: `docs/generating-sdks.md`
- API smoke testing: `docs/smoke-testing.md`
- Repository layout and conventions: `docs/repository-layout.md`

## Notes

- `Makefile` is the primary user interface.
- `scripts/` contains internal implementation used by `make` targets.
