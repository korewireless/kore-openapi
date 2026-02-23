# Generating SDKs

This repository includes a manifest-driven SDK generation workflow based on OpenAPI Generator.

Use `make` targets as the public interface. The `scripts/` directory is implementation detail.

## 1. Verify Prerequisites

```bash
make check-prereqs
```

See `docs/prerequisites.md` for details.

## 2. Discover Available Specs

```bash
make specs
```

## 3. Generate One Library

```bash
make generate-sdk SPEC=<spec-id> GENERATOR=<generator-name>
```

Example:

```bash
make generate-sdk SPEC=supersim-v1 GENERATOR=typescript-fetch
```

Output defaults to:

```text
generated/<spec-id>/<generator-name>
```

## 4. Common Options

```bash
make generate-sdk \
  SPEC=webhook-v1 \
  GENERATOR=python \
  OUT=generated/webhook/python \
  PACKAGE_NAME=kore_webhook \
  ADDITIONAL_PROPERTIES=packageVersion=1.0.0,projectName=KoreWebhook
```

## 5. Generate the Same Library for All Specs

```bash
make generate-sdk-all GENERATOR=typescript-fetch
```

## 6. Runtime Selection

Runtime is selected automatically in this order:

1. Docker (`openapitools/openapi-generator-cli:v7.12.0` by default)
2. Local `openapi-generator-cli`
3. `npx @openapitools/openapi-generator-cli`

To override Docker image for the underlying generator:

```bash
OPENAPI_GENERATOR_IMAGE=openapitools/openapi-generator-cli:v7.13.0 \
make generate-sdk SPEC=iam-v1 GENERATOR=java
```
