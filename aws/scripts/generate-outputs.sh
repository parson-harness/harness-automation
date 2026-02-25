#!/usr/bin/env bash
# Generate terraform outputs to a local config file
# Usage: ./scripts/generate-outputs.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="${AWS_DIR}/outputs.local.json"

cd "$AWS_DIR"

echo "Generating terraform outputs..."
terraform output -json > "$OUTPUT_FILE"

echo "Outputs saved to: $OUTPUT_FILE"
echo ""
echo "Key values:"
terraform output -json | jq -r '
  "  cluster_name:      " + .cluster_name.value,
  "  region:            " + .region.value,
  "  delegate_role_arn: " + .delegate_role_arn.value
'
