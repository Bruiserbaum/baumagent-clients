#!/usr/bin/env bash
# Generate a C# client from the OpenAPI spec using Kiota.
# Requires: kiota (https://learn.microsoft.com/en-us/openapi/kiota/install)
#
# Usage:
#   cd spec/codegen
#   ./generate-csharp.sh
#
# Output: clients/windows/BaumAgentClient/Generated/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPEC="$REPO_ROOT/spec/openapi.yaml"
OUT="$REPO_ROOT/clients/windows/BaumAgentClient/Generated"

command -v kiota >/dev/null 2>&1 || {
  echo "kiota not found."
  echo "Install via: dotnet tool install --global Microsoft.OpenApi.Kiota"
  exit 1
}

mkdir -p "$OUT"

kiota generate \
  --language CSharp \
  --class-name BaumAgentApiClient \
  --namespace-name BaumAgent.Generated \
  --openapi "$SPEC" \
  --output "$OUT" \
  --clean-output

echo "C# client generated at $OUT"
