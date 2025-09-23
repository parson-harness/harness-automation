#!/usr/bin/env bash
# Remote state init for ROOT (aws/) stack.
# - Keeps backend key consistent with your cluster/tag_owner naming.
# - Uses TF_VAR_* so "init" and "apply" share values.
# - Optional: --migrate to move existing local state to S3.

set -euo pipefail

# ---------- inputs ----------
# Read desired values from TF_VAR_* if set, else sensible defaults.
TF_TAG_OWNER="${TF_VAR_tag_owner:-${TAG_OWNER:-HarnessPOV}}"
TF_REGION="${TF_VAR_region:-${REGION:-us-east-1}}"
CLUSTER_BASE="${CLUSTER_BASE:-harness-eks}"         # mirrors var.cluster default
KEY_PREFIX="${KEY_PREFIX:-pov-root}"                # folder prefix in bucket
BACKEND_HCL="${BACKEND_HCL:-backend.hcl}"           # static bucket/table/enc config

MIGRATE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --migrate|-m) MIGRATE=true ;;
    --tag-owner) shift; TF_TAG_OWNER="$1" ;;
    --region) shift; TF_REGION="$1" ;;
    --cluster-base) shift; CLUSTER_BASE="$1" ;;
    --key-prefix) shift; KEY_PREFIX="$1" ;;
    --backend-hcl) shift; BACKEND_HCL="$1" ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift || true
done

# Export TF_VARs so "terraform apply" picks the same values
export TF_VAR_tag_owner="$TF_TAG_OWNER"
export TF_VAR_region="$TF_REGION"

# Build the same cluster name pattern your code uses: "${var.cluster}-${var.tag_owner}"
CLUSTER_TAG="${CLUSTER_BASE}-${TF_TAG_OWNER}"
TF_KEY="${KEY_PREFIX}/${TF_TAG_OWNER}/${CLUSTER_TAG}.tfstate"

echo "-> Initializing backend"
echo "   key=${TF_KEY}"
echo "   region=${TF_REGION}"

# NOTE: we override key/region even if backend.hcl has values
# so that init always matches current TAG_OWNER/REGION.
if $MIGRATE; then
  terraform init -reconfigure -migrate-state \
    -backend-config="${BACKEND_HCL}" \
    -backend-config="key=${TF_KEY}" \
    -backend-config="region=${TF_REGION}"
else
  terraform init -reconfigure \
    -backend-config="${BACKEND_HCL}" \
    -backend-config="key=${TF_KEY}" \
    -backend-config="region=${TF_REGION}"
fi

echo "✅ Backend ready. Next:"
echo "   terraform plan"
echo "   terraform apply"
