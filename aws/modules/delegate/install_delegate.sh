#!/usr/bin/env bash
set -euo pipefail

export TF_IN_AUTOMATION=1
export TF_CLI_ARGS="-no-color"

say()  { printf "\n==> %s\n" "$*"; }
warn() { printf "\nWARN: %s\n" "$*" >&2; }
err()  { printf "\nERROR: %s\n" "$*" >&2; exit 1; }

scrub() { printf %s "$1" | LC_ALL=C tr -d '\r\n\t' | LC_ALL=C tr -d '\000-\037'; }
prompt() {
  local v="$1"; shift
  if [ -z "${!v:-}" ]; then
    local ans
    read -rp "$*: " ans
    printf -v "$v" "%s" "$(scrub "$ans")"
    export "$v"
  fi
}
prompt_secret() {
  local v="$1"; shift
  if [ -z "${!v:-}" ]; then
    local ans
    read -rsp "$*: " ans
    printf '\n'
    printf -v "$v" "%s" "$(scrub "$ans")"
    export "$v"
  fi
}
is_valid_region() { [[ "$1" =~ ^[a-z]{2}(-[a-z]+)+-[0-9]+$ ]]; }
is_true() { [[ "${1,,}" == "true" || "$1" == "1" || "${1,,}" == "yes" || "${1,,}" == "y" ]]; }

tf_output_root() {
  local key="$1" raw val
  raw="$("$TERRAFORM_BIN" -chdir="$ROOT_DIR" output -raw "$key" 2>/dev/null || true)"
  val="$(printf %s "$raw" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g' | LC_ALL=C tr -d '\r' | LC_ALL=C tr -d '\000-\037')"
  if printf %s "$val" | grep -qi 'warning: no outputs found'; then
    echo ""
  else
    echo "$val"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"
PLAN_FILE="$(mktemp -t delegate-plan.XXXXXX)"
TFVARS_FILE="$(mktemp -t delegate-vars.XXXXXX.json)"
trap 'rm -f "$PLAN_FILE" "$TFVARS_FILE"' EXIT

export CLUSTER_NAME="${CLUSTER_NAME:-$(tf_output_root cluster_name)}"
export REGION="${REGION:-$(tf_output_root region)}"
export NS="${NS:-harness-delegate-ng}"
export SA="${SA:-harness-delegate}"
export HARNESS_ACCOUNT_ID="${HARNESS_ACCOUNT_ID:-}"
export DELEGATE_TOKEN="${DELEGATE_TOKEN:-}"
export DELEGATE_NAME="${DELEGATE_NAME:-}"
export DELEGATE_RELEASE_NAME="${DELEGATE_RELEASE_NAME:-}"
export MANAGER_ENDPOINT="${MANAGER_ENDPOINT:-https://app.harness.io}"
export DELEGATE_REPLICAS="${DELEGATE_REPLICAS:-1}"
export DELEGATE_K8S_PERMISSIONS_TYPE="${DELEGATE_K8S_PERMISSIONS_TYPE:-CLUSTER_ADMIN}"
export DELEGATE_POLL_FOR_TASKS="${DELEGATE_POLL_FOR_TASKS:-false}"
export DELEGATE_DESCRIPTION="${DELEGATE_DESCRIPTION:-}"
export DELEGATE_TAGS="${DELEGATE_TAGS:-}"
export DELEGATE_IMAGE_TAG="${DELEGATE_IMAGE_TAG:-}"
export DELEGATE_UPGRADER_ENABLED="${DELEGATE_UPGRADER_ENABLED:-false}"
export DELEGATE_UPGRADER_TOKEN="${DELEGATE_UPGRADER_TOKEN:-}"
export KUBECONFIG_UPDATE="${KUBECONFIG_UPDATE:-auto}"
export CONTEXT_NAME="${CONTEXT_NAME:-}"
export RUN_TERRAFORM_INIT="${RUN_TERRAFORM_INIT:-true}"
export AUTO_APPROVE="${AUTO_APPROVE:-false}"

prompt CLUSTER_NAME "EKS cluster name"
prompt REGION "AWS region (e.g. us-east-1)"
prompt HARNESS_ACCOUNT_ID "Harness Account ID"
prompt_secret DELEGATE_TOKEN "Harness Delegate Token"
prompt DELEGATE_NAME "Delegate name"

is_valid_region "$REGION" || err "REGION '$REGION' doesn't look like an AWS region (e.g., us-east-1)."

CLUSTER_NAME="$(scrub "$CLUSTER_NAME")"
REGION="$(scrub "$REGION")"
NS="$(scrub "$NS")"
SA="$(scrub "$SA")"
HARNESS_ACCOUNT_ID="$(scrub "$HARNESS_ACCOUNT_ID")"
DELEGATE_TOKEN="$(scrub "$DELEGATE_TOKEN")"
DELEGATE_NAME="$(scrub "$DELEGATE_NAME")"
DELEGATE_RELEASE_NAME="$(scrub "$DELEGATE_RELEASE_NAME")"
MANAGER_ENDPOINT="$(scrub "$MANAGER_ENDPOINT")"
DELEGATE_REPLICAS="$(scrub "$DELEGATE_REPLICAS")"
DELEGATE_K8S_PERMISSIONS_TYPE="$(scrub "$DELEGATE_K8S_PERMISSIONS_TYPE")"
DELEGATE_POLL_FOR_TASKS="$(scrub "$DELEGATE_POLL_FOR_TASKS")"
DELEGATE_DESCRIPTION="$(scrub "$DELEGATE_DESCRIPTION")"
DELEGATE_TAGS="$(scrub "$DELEGATE_TAGS")"
DELEGATE_IMAGE_TAG="$(scrub "$DELEGATE_IMAGE_TAG")"
DELEGATE_UPGRADER_ENABLED="$(scrub "$DELEGATE_UPGRADER_ENABLED")"
DELEGATE_UPGRADER_TOKEN="$(scrub "$DELEGATE_UPGRADER_TOKEN")"

if [ "$KUBECONFIG_UPDATE" = "auto" ]; then
  say "Updating kubeconfig for cluster '${CLUSTER_NAME}' in ${REGION}"
  aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME" >/dev/null
fi

if [ -n "$CONTEXT_NAME" ]; then
  say "Switching kubectl context to ${CONTEXT_NAME}"
  kubectl config use-context "$CONTEXT_NAME" >/dev/null
fi

if is_true "$RUN_TERRAFORM_INIT"; then
  say "Running terraform init"
  "$TERRAFORM_BIN" -chdir="$ROOT_DIR" init -input=false >/dev/null
fi

say "Preparing Terraform inputs for the delegate module"
python3 - <<'PY' > "$TFVARS_FILE"
import json
import os

def truthy(value: str) -> bool:
    return value.lower() in {"1", "true", "yes", "y"}

tags = [tag.strip() for tag in os.environ.get("DELEGATE_TAGS", "").split(",") if tag.strip()]

data = {
    "create_delegate": True,
    "delegate_namespace": os.environ["NS"],
    "delegate_service_account": os.environ["SA"],
    "delegate_name": os.environ["DELEGATE_NAME"],
    "delegate_account_id": os.environ["HARNESS_ACCOUNT_ID"],
    "delegate_token": os.environ["DELEGATE_TOKEN"],
    "delegate_manager_endpoint": os.environ["MANAGER_ENDPOINT"],
    "delegate_replicas": int(os.environ["DELEGATE_REPLICAS"]),
    "delegate_k8s_permissions_type": os.environ["DELEGATE_K8S_PERMISSIONS_TYPE"],
    "delegate_poll_for_tasks": truthy(os.environ["DELEGATE_POLL_FOR_TASKS"]),
    "delegate_description": os.environ.get("DELEGATE_DESCRIPTION", ""),
    "delegate_tags": tags,
    "delegate_upgrader_enabled": truthy(os.environ["DELEGATE_UPGRADER_ENABLED"]),
}

if os.environ.get("DELEGATE_RELEASE_NAME"):
    data["delegate_release_name"] = os.environ["DELEGATE_RELEASE_NAME"]

if os.environ.get("DELEGATE_IMAGE_TAG"):
    data["delegate_image_tag"] = os.environ["DELEGATE_IMAGE_TAG"]

if os.environ.get("DELEGATE_UPGRADER_TOKEN"):
    data["delegate_upgrader_token"] = os.environ["DELEGATE_UPGRADER_TOKEN"]

print(json.dumps(data))
PY

TARGET_ARGS=("-target=module.iam_irsa" "-target=module.delegate")

say "Planning delegate install/update"
"$TERRAFORM_BIN" -chdir="$ROOT_DIR" plan -input=false -var-file="$TFVARS_FILE" "${TARGET_ARGS[@]}" -out="$PLAN_FILE"

if ! is_true "$AUTO_APPROVE"; then
  local_confirm=""
  read -rp "Apply this delegate plan? [y/N]: " local_confirm
  if ! is_true "$local_confirm"; then
    err "Cancelled."
  fi
fi

say "Applying delegate plan"
"$TERRAFORM_BIN" -chdir="$ROOT_DIR" apply "$PLAN_FILE"

RELEASE_OUT="$(tf_output_root delegate_release_name)"
NS_OUT="$(tf_output_root delegate_namespace)"
SA_OUT="$(tf_output_root delegate_service_account_name)"
IMG_OUT="$(tf_output_root delegate_image)"

say "Done ✅  Release='${RELEASE_OUT:-$DELEGATE_NAME}'  Delegate='${DELEGATE_NAME}'  Namespace='${NS_OUT:-$NS}'"
[ -n "$SA_OUT" ] && echo "ServiceAccount: $SA_OUT"
[ -n "$IMG_OUT" ] && echo "Image: $IMG_OUT"
