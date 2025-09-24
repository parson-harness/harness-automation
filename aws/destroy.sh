#!/usr/bin/env bash
# Decoupled destroy helper (macOS/Bash 3.2 compatible, no arrays required)
# - Delegate uninstall (by --delegate-name, --release, or --pattern)
# - Optional: destroy permissions (IRSA) and/or cluster
# - Reads Terraform outputs from root (aws/) if present; falls back to env
set -euo pipefail

say()  { printf "\n==> %s\n" "$*"; }
warn() { printf "\nWARN: %s\n" "$*" >&2; }
err()  { printf "\nERROR: %s\n" "$*" >&2; exit 1; }

# ---------- defaults ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$SCRIPT_DIR}"       # run from aws/ root ideally
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"

REGION="${REGION:-}"
CLUSTER_NAME="${CLUSTER_NAME:-}"
NS="${NS:-harness-delegate-ng}"
SA="${SA:-harness-delegate}"

DO_DELEGATE=false
DO_PERMISSIONS=false
DO_CLUSTER=false
DO_ALL=false

CONFIRM=false
LIST_ONLY=false
DELETE_NAMESPACE=false

# selections as simple space-separated strings (Bash 3.2 safe)
DELEGATE_NAMES_S=""
RELEASES_S=""
PATTERNS_S=""

# ---------- helpers ----------
tf_output_root() {
  local key="$1" val=""
  if val="$("$TERRAFORM_BIN" -chdir="$ROOT_DIR" output -raw "$key" 2>/dev/null || true)"; then :; fi
  if [ -z "$val" ] || printf %s "$val" | grep -q "Warning: No outputs found"; then
    echo ""
  else
    echo "$val"
  fi
}

sanitize_release() {
  echo "$1" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//' \
  | cut -c1-53
}

glob_to_ere() { # simple * and ?
  local g="$1"
  g="${g//./\\.}"; g="${g//\*/.*}"; g="${g//\?/.}"
  echo "^${g}$"
}

confirm() {
  if $CONFIRM; then return 0; fi
  printf "Proceed? [y/N] "
  read ans || true
  case "$ans" in y|Y|yes|YES) return 0;; *) echo "Aborted."; exit 1;; esac
}

usage() {
  cat <<EOF
Usage: $0 [options]

Delegate targets
  --delegate                         Uninstall delegate(s)
  --delegate-name <name>             Target by Delegate name (maps to Helm release via sanitize)
  --release <helm-release>           Target exact Helm release
  --pattern <glob>                   Target releases by glob (e.g., "pov-*")
  --list                             List matching releases and exit
  --delete-namespace                 Delete namespace after uninstall (if empty)

Infra targets (optional)
  --permissions                      Destroy IRSA/permissions (module: iam_irsa)
  --cluster                          Destroy EKS/VPC (module: eks)
  --all                              Do everything (delegate -> permissions -> cluster)

General
  --ns <namespace>                   Namespace (default: harness-delegate-ng)
  --region <aws-region>              e.g., us-east-1 (defaults from terraform output "region")
  --cluster-name <eks-name>          (defaults from terraform output "cluster_name")
  --yes                              Non-interactive
  -h | --help                        Show help
EOF
}

# ---------- args ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --delegate) DO_DELEGATE=true;;
    --permissions) DO_PERMISSIONS=true;;
    --cluster) DO_CLUSTER=true;;
    --all) DO_ALL=true;;
    --delegate-name) shift; DELEGATE_NAMES_S="${DELEGATE_NAMES_S}${DELEGATE_NAMES_S:+ }$1";;
    --release) shift; RELEASES_S="${RELEASES_S}${RELEASES_S:+ }$1";;
    --pattern) shift; PATTERNS_S="${PATTERNS_S}${PATTERNS_S:+ }$1";;
    --list) LIST_ONLY=true;;
    --delete-namespace) DELETE_NAMESPACE=true;;
    --ns) shift; NS="$1";;
    --region) shift; REGION="$1";;
    --cluster-name) shift; CLUSTER_NAME="$1";;
    --yes) CONFIRM=true;;
    -h|--help) usage; exit 0;;
    *) err "Unknown arg: $1";;
  esac
  shift || true
done

$DO_ALL && { DO_DELEGATE=true; DO_PERMISSIONS=true; DO_CLUSTER=true; }

if ! $DO_DELEGATE && ! $DO_PERMISSIONS && ! $DO_CLUSTER; then
  usage; exit 1
fi

# ---------- resolve TF outputs ----------
REGION="${REGION:-$(tf_output_root region)}"
CLUSTER_NAME="${CLUSTER_NAME:-$(tf_output_root cluster_name)}"

# ---------- kubeconfig ----------
if [ -n "$REGION" ] && [ -n "$CLUSTER_NAME" ]; then
  say "Updating kubeconfig for cluster '$CLUSTER_NAME' in $REGION"
  aws eks --region "$REGION" update-kubeconfig --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
fi

# ---------- selection ----------
resolve_targets() {
  # build newline-separated list
  local out="" n r p rgx all rel

  # from --delegate-name (map to sanitized release)
  for n in $DELEGATE_NAMES_S; do
    out="${out}$(sanitize_release "$n")"$'\n'
  done

  # from --release (as-is)
  for r in $RELEASES_S; do
    out="${out}${r}"$'\n'
  done

  # from --pattern
  if [ -n "$PATTERNS_S" ]; then
    all="$(helm -n "$NS" list -q 2>/dev/null || true)"
    for p in $PATTERNS_S; do
      rgx="$(glob_to_ere "$p")"
      # iterate releases
      printf "%s\n" "$all" | while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        echo "$rel" | grep -Eq "$rgx" && out="${out}${rel}"$'\n'
      done
    done
  fi

  # dedupe and print
  if [ -n "$out" ]; then
    printf "%s" "$out" | awk 'NF && !seen[$0]++'
  fi
}

uninstall_delegate_release() {
  local rel="$1"
  say "Uninstalling Helm release '$rel' in namespace '$NS'"
  helm -n "$NS" uninstall "$rel" --wait --timeout 5m >/dev/null 2>&1 || warn "Release '$rel' not found or already removed."

  # Clean upgrader CronJobs (label-based)
  say "Cleaning upgrader CronJobs and leftovers for '$rel'"
  kubectl -n "$NS" delete cronjob -l "app.kubernetes.io/instance=${rel},app.kubernetes.io/name=harness-delegate-ng" --ignore-not-found=true >/dev/null 2>&1 || true

  # Fallback heuristic if labels differ
  for cj in $(kubectl -n "$NS" get cronjobs -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
    case "$cj" in
      *"$rel"*upgrad* ) kubectl -n "$NS" delete cronjob "$cj" --ignore-not-found=true >/dev/null 2>&1 || true ;;
    esac
  done

  # Secrets/configmaps tied to release
  kubectl -n "$NS" delete secret -l "app.kubernetes.io/instance=${rel}" --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl -n "$NS" delete configmap -l "app.kubernetes.io/instance=${rel}" --ignore-not-found=true >/dev/null 2>&1 || true
}

delete_namespace_if_requested() {
  $DELETE_NAMESPACE || return 0
  say "Attempting to delete namespace '$NS' (if empty)"
  local remaining
  remaining="$(helm -n "$NS" list -q 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$remaining" = "0" ]; then
    kubectl delete namespace "$NS" --ignore-not-found=true >/dev/null 2>&1 || true
  else
    warn "Namespace '$NS' still has Helm releases; not deleting."
  fi
}

destroy_permissions() {
  say "Destroying IAM/IRSA permissions via Terraform (module iam_irsa)"
  ( cd "$ROOT_DIR" && $TERRAFORM_BIN destroy -target=module.iam_irsa -auto-approve )
}

destroy_cluster() {
  say "Destroying EKS + VPC via Terraform (module eks)"
  ( cd "$ROOT_DIR" && $TERRAFORM_BIN destroy -target=module.eks -auto-approve )
}

# ---------- main ----------
if $DO_DELEGATE; then
  TARGETS_STR="$(resolve_targets || true)"

  if $LIST_ONLY; then
    say "Matching releases in namespace '$NS':"
    if [ -z "$TARGETS_STR" ]; then echo "(none)"; else printf ' - %s\n' $TARGETS_STR; fi
    exit 0
  fi

  # turn into a list safely for Bash 3.2
  if [ -z "${TARGETS_STR:-}" ]; then
    warn "No delegate releases matched your selection in namespace '$NS'."
  else
    say "About to uninstall these releases in ns '$NS':"
    printf ' - %s\n' $TARGETS_STR
    confirm
    for rel in $TARGETS_STR; do
      [ -n "$rel" ] && uninstall_delegate_release "$rel"
    done
    delete_namespace_if_requested
  fi
fi

if $DO_PERMISSIONS; then
  confirm
  destroy_permissions
fi

if $DO_CLUSTER; then
  confirm
  destroy_cluster
fi

say "Done."
