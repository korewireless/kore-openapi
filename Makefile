SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help check-prereqs specs smoke generate-sdk generate-sdk-all

help:
	@echo "Targets:"
	@echo "  make check-prereqs"
	@echo "      Validate required local tooling (make, bash, jq, curl, and generator runtime)"
	@echo ""
	@echo "  make specs"
	@echo "      List available OpenAPI specs from specs/catalog.json"
	@echo ""
	@echo "  make smoke [SPEC=<spec-id[,spec-id...]>] [STRICT=1] [DRY_RUN=1] [TIMEOUT=<seconds>]"
	@echo "      Run per-spec API smoke checks using cataloged base URLs + inferred endpoints"
	@echo ""
	@echo "  make generate-sdk SPEC=<spec-id> GENERATOR=<name> [OUT=<output-path>] [PACKAGE_NAME=<name>] [ADDITIONAL_PROPERTIES=<k=v,...>]"
	@echo "      Generate a client library for one spec"
	@echo ""
	@echo "  make generate-sdk-all GENERATOR=<name>"
	@echo "      Generate the same client library for all specs"

check-prereqs:
	@echo "Checking prerequisites..."
	@command -v make >/dev/null 2>&1 || { echo "Missing required tool: make"; exit 1; }
	@command -v bash >/dev/null 2>&1 || { echo "Missing required tool: bash"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "Missing required tool: jq"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "Missing required tool: curl"; exit 1; }
	@if command -v docker >/dev/null 2>&1; then \
		echo "Generator runtime: docker"; \
	elif command -v openapi-generator-cli >/dev/null 2>&1; then \
		echo "Generator runtime: openapi-generator-cli"; \
	elif command -v npx >/dev/null 2>&1; then \
		echo "Generator runtime: npx (@openapitools/openapi-generator-cli)"; \
	else \
		echo "Missing generator runtime: install Docker or openapi-generator-cli or Node.js+npx"; \
		exit 1; \
	fi
	@echo "Prerequisites OK."

specs:
	@./scripts/list-specs.sh

smoke:
	@cmd=(./scripts/smoke-apis.sh); \
	if [[ -n "$(SPEC)" ]]; then cmd+=(--spec "$(SPEC)"); fi; \
	if [[ "$(STRICT)" == "1" || "$(STRICT)" == "true" ]]; then cmd+=(--strict); fi; \
	if [[ "$(DRY_RUN)" == "1" || "$(DRY_RUN)" == "true" ]]; then cmd+=(--dry-run); fi; \
	if [[ -n "$(TIMEOUT)" ]]; then cmd+=(--timeout "$(TIMEOUT)"); fi; \
	"$${cmd[@]}"

generate-sdk:
	@if [[ -z "$(SPEC)" || -z "$(GENERATOR)" ]]; then \
		echo "Usage: make generate-sdk SPEC=<spec-id> GENERATOR=<name> [OUT=<output-path>] [PACKAGE_NAME=<name>] [ADDITIONAL_PROPERTIES=<k=v,...>]"; \
		exit 1; \
	fi
	@cmd=(./scripts/generate-sdk.sh --spec "$(SPEC)" --generator "$(GENERATOR)"); \
	if [[ -n "$(OUT)" ]]; then cmd+=(--output "$(OUT)"); fi; \
	if [[ -n "$(PACKAGE_NAME)" ]]; then cmd+=(--package-name "$(PACKAGE_NAME)"); fi; \
	if [[ -n "$(ADDITIONAL_PROPERTIES)" ]]; then cmd+=(--additional-properties "$(ADDITIONAL_PROPERTIES)"); fi; \
	"$${cmd[@]}"

generate-sdk-all:
	@if [[ -z "$(GENERATOR)" ]]; then \
		echo "Usage: make generate-sdk-all GENERATOR=<name>"; \
		exit 1; \
	fi
	@while IFS= read -r spec_id; do \
		./scripts/generate-sdk.sh --spec "$$spec_id" --generator "$(GENERATOR)" --output "generated/$$spec_id/$(GENERATOR)"; \
	done < <(./scripts/list-specs.sh --ids)
