#!/usr/bin/env bash
# Install a Harness Kubernetes Delegate via Helm.
# - Enforces unique DELEGATE_NAME per namespace by mapping it 1:1 to the Helm release name
# - Prompts for missing inputs (cluster, region, account, token, etc.)
# - Supports IRSA role ARN injection
# - Installs multiple delegates in the same cluster by using different DELEGATE_NAMEs
#
# Requirements: aws, kubectl, helm

set -euo pipefail

say() { printf "\n==> %s\n" "$*"; }
err() { printf "\nERROR: %s\n" "$*" >&2; exit 1; }

# ---------- helpers ----------
prompt() {
  local var="$1"; shift
  local msg="$*"
  if [ -z "${!var:-}" ]; then
    read -rp "$msg: " _val
    export "$var"="$_val"
  fi
}

sanitize_release() {
  # lowercase, keep alnum and dash, collapse repeats, trim to <=53 chars
  echo "$1" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//' \
  | cut -c1-53
}

# Try to read outputs from Terraform sub-stacks if present
tf_out() {
  # usage: tf_out <dir> <output_name>
  local dir="${1:-.}" key="${2:-}"
  terraform -chdir="$dir" output -raw "$key" 2>/dev/null || true
}

# ---------- defaults / env ----------
EKS_DIR="${EKS_DIR:-$(cd "$(dirname "$0")/.." && pwd)/eks}"
IRSA_DIR="${IRSA_DIR:-$(cd "$(dirname "$0")/.." && pwd)/iam-irsa}"

# Resolve cluster/region/namespace/sa from TF if available, else env, else prompt
export CLUSTER_NAME="${CLUSTER_NAME:-$(tf_out "$EKS_DIR" cluster_name)}"
export REGION="${REGION:-$(tf_out "$EKS_DIR" region)}"
export NS="${NS:-$(tf_out "$EKS_DIR" delegate_namespace)}"
export SA="${SA:-$(tf_out "$EKS_DIR" delegate_service_account)}"
export IRSA_ROLE_ARN="${IRSA_ROLE_ARN:-$(tf_out "$IRSA_DIR" role_arn)}"

# Required Harness inputs (prompt if missing)
export HARNESS_ACCOUNT_ID="${HARNESS_ACCOUNT_ID:-}"
export DELEGATE_TOKEN="${DELEGATE_TOKEN:-}"
export DELEGATE_NAME="${DELEGATE_NAME:-}"

# Optional knobs
export MANAGER_ENDPOINT="${MANAGER_ENDPOINT:-https://app.harness.io/gratis}"
export DELEGATE_REPLICAS="${DELEGATE_REPLICAS:-1}"
export DELEGATE_IMAGE="${DELEGATE_IMAGE:-}"   # override image (optional)
export KUBECONFIG_UPDATE="${KUBECONFIG_UPDATE:-auto}"  # auto/skip
export CONTEXT_NAME="${CONTEXT_NAME:-}"       # optional explicit kube context

# ---------- prompts for missing requireds ----------
prompt CLUSTER_NAME        "EKS cluster name"
prompt REGION              "AWS region (e.g. us-east-1)"
NS="${NS:-harness-delegate-ng}"
SA="${SA:-harness-delegate}"
prompt HARNESS_ACCOUNT_ID  "Harness Account ID"
prompt DELEGATE_TOKEN      "Harness Delegate Token"
prompt DELEGATE_NAME       "Delegate name (unique per namespace)"

# Release name is a sanitized copy of DELEGATE_NAME (1:1)
RELEASE_NAME="${RELEASE_NAME:-$(sanitize_release "$DELEGATE_NAME")}"
[ -n "$RELEASE_NAME" ] || err "Release name derived from DELEGATE_NAME is empty after sanitization."

# If user wants to supply IRSA, ask once if still empty
if [ -z "${IRSA_ROLE_ARN:-}" ]; then
  read -rp "IRSA role ARN (optional, press Enter to skip): " maybe_irsa || true
  IRSA_ROLE_ARN="${IRSA_ROLE_ARN:-$maybe_irsa}"
fi

# ---------- kube context ----------
if [ "${KUBECONFIG_UPDATE}" = "auto" ]; then
  say "Updating kubeconfig for cluster '${CLUSTER_NAME}' in ${REGION}"
  aws eks --region "${REGION}" update-kubeconfig --name "${CLUSTER_NAME}" >/dev/null
fi
if [ -n "${CONTEXT_NAME}" ]; then
  say "Switching kubectl context to ${CONTEXT_NAME}"
  kubectl config use-context "${CONTEXT_NAME}" >/dev/null
fi

# ---------- namespace ----------
say "Ensuring namespace '${NS}' exists"
kubectl get ns "${NS}" >/dev/null 2>&1 || kubectl create ns "${NS}"

# ---------- ensure helm repo ----------
say "Ensuring Harness Helm repo is configured"
helm repo add harness https://app.harness.io/storage/harness-download/delegate-helm/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

# ---------- uniqueness check (by release name) ----------
if helm -n "${NS}" status "${RELEASE_NAME}" >/dev/null 2>&1; then
  err "A Helm release named '${RELEASE_NAME}' already exists in namespace '${NS}'. Choose a different DELEGATE_NAME."
fi

# ---------- install / upgrade ----------
say "Installing delegate '${DELEGATE_NAME}' as Helm release '${RELEASE_NAME}' in ns '${NS}'"
set -x
helm upgrade --install "${RELEASE_NAME}" harness/harness-delegate-ng \
  --namespace "${NS}" \
  --create-namespace \
  --set-string "delegateName=${DELEGATE_NAME}" \
  --set-string "accountId=${HARNESS_ACCOUNT_ID}" \
  --set-string "delegateToken=${DELEGATE_TOKEN}" \
  --set-string "managerEndpoint=${MANAGER_ENDPOINT}" \
  --set "replicas=${DELEGATE_REPLICAS}" \
  --set-string "k8sServiceAccount=${SA}" \
  ${IRSA_ROLE_ARN:+--set-string "irsaRoleArn=${IRSA_ROLE_ARN}"} \
  ${DELEGATE_IMAGE:+--set-string "delegateDockerImage=${DELEGATE_IMAGE}"}
set +x

say "Done ✅  Release='${RELEASE_NAME}'  Delegate='${DELEGATE_NAME}'  Namespace='${NS}'"
say "Tip: To uninstall later by delegate name, run destroy.sh with: --delegate --delegate-name '${DELEGATE_NAME}'"
