#!/usr/bin/env bash
# Generate a Swift client package from the OpenAPI spec.
# Requires: swift-openapi-generator (https://github.com/apple/swift-openapi-generator)
#
# Usage:
#   cd spec/codegen
#   ./generate-swift.sh
#
# Output: clients/macos/Sources/BaumAgentClient/Generated/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPEC="$REPO_ROOT/spec/openapi.yaml"
OUT="$REPO_ROOT/clients/macos/Sources/BaumAgentClient/Generated"

command -v swift-openapi-generator >/dev/null 2>&1 || {
  echo "swift-openapi-generator not found."
  echo "Install via: brew install apple/tools/swift-openapi-generator"
  exit 1
}

mkdir -p "$OUT"

swift-openapi-generator generate \
  --input "$SPEC" \
  --output "$OUT" \
  --config "$SCRIPT_DIR/swift-openapi-generator-config.yaml"

echo "Swift client generated at $OUT"
