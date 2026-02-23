# API Smoke Testing

Use smoke checks to quickly verify that each cataloged API endpoint is reachable and responding.

## Quick Start

```bash
make smoke
```

Default behavior is pragmatic for API reachability:

- PASS on `2xx`, `3xx`, or `4xx` responses
- FAIL on `5xx` responses or network/curl errors

This helps distinguish "service reachable" from "service unavailable."

## Portal Split

- Build portal APIs: `supersim-v1`, `programmable-wireless-v1`, `webhook-v1`, `iam-v1`, `api-clients-*`
- Developer portal APIs: `connectivity-pro-v1`, `sms-v1`

The smoke output includes a `PORTAL` column so each request is clearly tagged.

## Common Usage

Run only one or more spec IDs:

```bash
make smoke SPEC=sms-v1
make smoke SPEC=connectivity-pro-v1,sms-v1
```

Dry run (show planned requests without calling APIs):

```bash
make smoke DRY_RUN=1
```

Strict mode (PASS only on `2xx`):

```bash
make smoke STRICT=1
```

Custom timeout:

```bash
make smoke TIMEOUT=30
```

## Auth Variables

Set these environment variables when required by your APIs:

- Common fallback:
  - `KORE_BEARER_TOKEN`
  - `KORE_API_KEY`
- Build portal:
  - `KORE_BUILD_BEARER_TOKEN`
  - `KORE_BUILD_API_KEY`
  - `KORE_BUILD_CLIENT_ID` and `KORE_BUILD_CLIENT_SECRET`
  - `KORE_CLIENT_ID` and `KORE_CLIENT_SECRET` are accepted aliases
  - OAuth token endpoint: `https://api.korewireless.com/api-services/v1/auth/token`
- Developer portal (ConnectivityPro/SMS):
  - `KORE_DEVELOPER_BEARER_TOKEN`
  - `KORE_DEVELOPER_API_KEY`
  - `KORE_DEVELOPER_CLIENT_ID` and `KORE_DEVELOPER_CLIENT_SECRET`
  - OAuth token endpoint: `https://api.korewireless.com/Api/api/token`

Example:

```bash
KORE_BEARER_TOKEN=... \
KORE_API_KEY=... \
make smoke
```

Example with split credentials:

```bash
KORE_BUILD_CLIENT_ID=... \
KORE_BUILD_CLIENT_SECRET=... \
KORE_DEVELOPER_CLIENT_ID=... \
KORE_DEVELOPER_CLIENT_SECRET=... \
KORE_DEVELOPER_API_KEY=... \
make smoke
```

## Notes

- The smoke script infers one lightweight endpoint per spec from its OpenAPI file.
- It is a reachability check, not a full contract/functional test suite.
