#!/usr/bin/env bash
# Remote state init for ROOT (aws/) stack.
# Option A: trust backend.hcl for bucket/key/locks; don't override them here.

set -euo pipefail

# ---------- inputs ----------
TF_TAG_OWNER="${TF_VAR_tag_owner:-${TAG_OWNER:-HarnessPOV}}"
TF_REGION="${TF_VAR_region:-${REGION:-us-east-1}}"
BACKEND_HCL="${BACKEND_HCL:-backend.hcl}"   # contains bucket/key/region/table/encrypt

MIGRATE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --migrate|-m) MIGRATE=true ;;
    --tag-owner) shift; TF_TAG_OWNER="$1" ;;
    --region) shift; TF_REGION="$1" ;;
    --backend-hcl) shift; BACKEND_HCL="$1" ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift || true
done

# Make these available to terraform plan/apply
export TF_VAR_tag_owner="$TF_TAG_OWNER"
export TF_VAR_region="$TF_REGION"
# (optional, if you use var.cluster)
# export TF_VAR_cluster="${TF_VAR_cluster:-${CLUSTER_BASE:-harness-eks}}"

echo "-> Initializing backend using ${BACKEND_HCL}"
echo "   region=${TF_REGION}  (only for providers; backend key is read from ${BACKEND_HCL})"

INIT_FLAGS=(-reconfigure -backend-config="${BACKEND_HCL}")
$MIGRATE && INIT_FLAGS+=(-migrate-state)

terraform init "${INIT_FLAGS[@]}"

echo "✅ Backend ready. Next:"
echo "   terraform plan"
echo "   terraform apply"
