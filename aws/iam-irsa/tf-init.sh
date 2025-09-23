#!/usr/bin/env bash
# Remote state init for IAM/IRSA-only stack (aws/iam-irsa).
# - Each cluster gets its own state key.
# - Uses TF_VAR_* for consistency with apply.

set -euo pipefail

# Required when running IRSA standalone
: "${CLUSTER_NAME:?Set CLUSTER_NAME to your existing EKS cluster name}"

TF_TAG_OWNER="${TF_VAR_tag_owner:-${TAG_OWNER:-HarnessPOV}}"
TF_REGION="${TF_VAR_region:-${REGION:-us-east-1}}"
KEY_PREFIX="${KEY_PREFIX:-pov-iam-irsa}"
BACKEND_HCL="${BACKEND_HCL:-backend.hcl}"

MIGRATE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --migrate|-m) MIGRATE=true ;;
    --tag-owner) shift; TF_TAG_OWNER="$1" ;;
    --region) shift; TF_REGION="$1" ;;
    --key-prefix) shift; KEY_PREFIX="$1" ;;
    --backend-hcl) shift; BACKEND_HCL="$1" ;;
    --cluster-name) shift; CLUSTER_NAME="$1" ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift || true
done

export TF_VAR_tag_owner="$TF_TAG_OWNER"
export TF_VAR_region="$TF_REGION"
export TF_VAR_cluster_name="${CLUSTER_NAME}"

TF_KEY="${KEY_PREFIX}/${TF_TAG_OWNER}/${CLUSTER_NAME}.tfstate"

echo "-> Initializing backend (iam-irsa)"
echo "   key=${TF_KEY}"
echo "   region=${TF_REGION}"

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
echo "   terraform apply -auto-approve"
