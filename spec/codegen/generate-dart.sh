#!/usr/bin/env bash
# Generate a Dart client from the OpenAPI spec using openapi-generator-cli.
# Requires: openapi-generator-cli (https://openapi-generator.tech/docs/installation)
#           Java 11+ on PATH
#
# Usage:
#   cd spec/codegen
#   ./generate-dart.sh
#
# Output: clients/android/lib/generated/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPEC="$REPO_ROOT/spec/openapi.yaml"
OUT="$REPO_ROOT/clients/android/lib/generated"

command -v openapi-generator-cli >/dev/null 2>&1 || {
  echo "openapi-generator-cli not found."
  echo "Install via: npm install -g @openapitools/openapi-generator-cli"
  exit 1
}

mkdir -p "$OUT"

openapi-generator-cli generate \
  --input-spec "$SPEC" \
  --generator-name dart-dio \
  --output "$OUT" \
  --additional-properties=pubName=baumagent_api,pubAuthor=Bruiserbaum,nullableFields=true

echo "Dart client generated at $OUT"
