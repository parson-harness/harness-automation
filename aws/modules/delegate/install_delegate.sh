#!/usr/bin/env bash
# Harness Delegate installer (Helm) — robust quoting + latest image resolution
set -euo pipefail

say()  { printf "\n==> %s\n" "$*"; }
warn() { printf "\nWARN: %s\n" "$*" >&2; }
err()  { printf "\nERROR: %s\n" "$*" >&2; exit 1; }

sanitize_release() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//' | cut -c1-53
}
is_valid_region() { [[ "$1" =~ ^[a-z]{2}(-[a-z]+)+-[0-9]+$ ]]; }
prompt() { local v="$1"; shift; [ -n "${!v:-}" ] || { read -rp "$*: " _; export "$v"="$_"; }; }
yamlq() { local s=${1//\'/\'\'}; printf "'%s'" "$s"; }

# Read a Terraform output from root (aws/) safely
tf_output_root() {
  local key="$1" val=""
  if val="$("$TERRAFORM_BIN" -chdir="$ROOT_DIR" output -raw "$key" 2>/dev/null || true)"; then :; fi
  [[ -z "$val" || "$val" == *"Warning: No outputs found"* ]] && echo "" || echo "$val"
}

# ---- ONLY echo the image to stdout; send logs to stderr ----
resolve_latest_delegate_image() {
  [ -n "${DELEGATE_IMAGE:-}" ] && { echo "$DELEGATE_IMAGE"; return 0; }

  local hub="https://hub.docker.com/v2/repositories/harness/delegate/tags/?page_size=100&ordering=last_updated"
  local tag=""
  say "Resolving latest harness/delegate tag from Docker Hub…" >&2
  if command -v jq >/dev/null 2>&1; then
    tag="$(curl -fsSL "$hub" | jq -r '.results[].name' | grep -E '^[0-9]{2}\.[0-9]{2}\.[0-9]{5}$' | sort -V | tail -n1 || true)"
  else
    tag="$(curl -fsSL "$hub" | tr ',' '\n' | grep -oE '"name":[[:space:]]*"[^"]+"' \
          | sed -E 's/.*"name":[[:space:]]*"([^"]+)".*/\1/' | grep -E '^[0-9]{2}\.[0-9]{2}\.[0-9]{5}$' | sort -V | tail -n1 || true)"
  fi
  local prefix="${DELEGATE_IMAGE_PREFIX:-us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate}"
  if [ -n "$tag" ]; then echo "${prefix}:${tag}"; return 0; fi

  warn "Could not determine latest tag from Docker Hub."
  if [ -n "${HARNESS_API_KEY:-}" ] && [ -n "${HARNESS_ACCOUNT_ID:-}" ]; then
    local api="${HARNESS_API_BASE:-https://app.harness.io}" ver_json version
    ver_json="$(curl -sfSL -H "x-api-key: ${HARNESS_API_KEY}" \
      "${api}/ng/api/delegate-setup/latest-supported-version?accountIdentifier=${HARNESS_ACCOUNT_ID}" || true)"
    version="$(printf '%s' "$ver_json" | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*"\([0-9][0-9]\.[0-9][0-9]\.[0-9]\{5\}\)".*/\1/p')"
    if [ -n "$version" ]; then echo "${prefix}:${version}"; return 0; fi
    warn "Harness API fallback did not return a version."
  fi
  echo ""  # no override
}

# ---- locate root / terraform ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"

# ---- inputs / env ----
export CLUSTER_NAME="${CLUSTER_NAME:-$(tf_output_root cluster_name)}"
export REGION="${REGION:-$(tf_output_root region)}"
export NS="${NS:-harness-delegate-ng}"
export SA="${SA:-harness-delegate}"
export HARNESS_ACCOUNT_ID="${HARNESS_ACCOUNT_ID:-}"
export DELEGATE_TOKEN="${DELEGATE_TOKEN:-}"
export DELEGATE_NAME="${DELEGATE_NAME:-}"
export MANAGER_ENDPOINT="${MANAGER_ENDPOINT:-https://app.harness.io/gratis}"
export DELEGATE_REPLICAS="${DELEGATE_REPLICAS:-1}"
export IRSA_ROLE_ARN="${IRSA_ROLE_ARN:-$(tf_output_root delegate_role_arn)}"
export KUBECONFIG_UPDATE="${KUBECONFIG_UPDATE:-auto}"
export CONTEXT_NAME="${CONTEXT_NAME:-}"

# ---- prompts / validate ----
prompt CLUSTER_NAME        "EKS cluster name"
prompt REGION              "AWS region (e.g. us-east-1)"
prompt HARNESS_ACCOUNT_ID  "Harness Account ID"
prompt DELEGATE_TOKEN      "Harness Delegate Token"
prompt DELEGATE_NAME       "Delegate name (unique per namespace)"
is_valid_region "$REGION" || err "REGION '$REGION' doesn't look like an AWS region (e.g., us-east-1)."

RELEASE_NAME="${RELEASE_NAME:-$(sanitize_release "$DELEGATE_NAME")}"
[ -n "$RELEASE_NAME" ] || err "Release name derived from DELEGATE_NAME is empty."

# ---- kube context ----
[ "$KUBECONFIG_UPDATE" = "auto" ] && { say "Updating kubeconfig for cluster '${CLUSTER_NAME}' in ${REGION}"; aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME" >/dev/null; }
[ -n "$CONTEXT_NAME" ] && { say "Switching kubectl context to ${CONTEXT_NAME}"; kubectl config use-context "$CONTEXT_NAME" >/dev/null; }

# ---- namespace / SA ----
say "Ensuring namespace '${NS}' and ServiceAccount '${SA}' exist"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"
kubectl -n "$NS" get sa "$SA" >/dev/null 2>&1 || kubectl -n "$NS" create serviceaccount "$SA"

# ---- helm repo ----
say "Ensuring Harness Delegate Helm repo is configured"
helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

# ---- uniqueness check ----
if helm -n "$NS" status "$RELEASE_NAME" >/dev/null 2>&1; then
  err "A Helm release named '$RELEASE_NAME' already exists in namespace '$NS'. Choose a different DELEGATE_NAME."
fi

# ---- image (latest) ----
IMG="$(resolve_latest_delegate_image || true)"
[ -n "$IMG" ] && say "Using delegate image: $IMG"

# ---- values.yaml (quoted) ----
TMP="$(mktemp -t delegate-values.XXXX.yaml)"; trap 'rm -f "$TMP"' EXIT
{
  echo "delegateName: $(yamlq "$DELEGATE_NAME")"
  echo "accountId: $(yamlq "$HARNESS_ACCOUNT_ID")"
  echo "delegateToken: $(yamlq "$DELEGATE_TOKEN")"
  echo "managerEndpoint: $(yamlq "$MANAGER_ENDPOINT")"
  echo "k8sServiceAccount: $(yamlq "$SA")"
  echo "replicas: ${DELEGATE_REPLICAS}"
  [ -n "$IRSA_ROLE_ARN" ] && echo "irsaRoleArn: $(yamlq "$IRSA_ROLE_ARN")"
  [ -n "$IMG" ] && echo "delegateDockerImage: $(yamlq "$IMG")"
} > "$TMP"

# ---- install/upgrade ----
say "Installing delegate '${DELEGATE_NAME}' as Helm release '${RELEASE_NAME}' in ns '${NS}'"
helm upgrade --install "$RELEASE_NAME" harness-delegate/harness-delegate-ng \
  --namespace "$NS" --create-namespace -f "$TMP"

say "Waiting for deployment rollout…"
kubectl -n "$NS" rollout status "deploy/${DELEGATE_NAME}" --timeout=5m || true
kubectl -n "$NS" get pods -o wide

say "Done ✅  Release='${RELEASE_NAME}'  Delegate='${DELEGATE_NAME}'  Namespace='${NS}'"
echo "Tip: uninstall with: ./destroy.sh --delegate --delegate-name '${DELEGATE_NAME}' --yes"