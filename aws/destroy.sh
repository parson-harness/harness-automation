#!/usr/bin/env bash
# Teardown helper with decoupled options:
#   --delegate       uninstall delegate(s) via Helm (and upgrader CronJob)
#   --permissions    terraform destroy in aws/iam-irsa
#   --cluster        terraform destroy in aws/eks
#   --all            run delegate -> permissions -> cluster
#
# Extras for targeting delegates:
#   --delegate-name <name>  uninstall release derived from this DELEGATE_NAME
#   --release <name>        uninstall this Helm release (repeatable)
#   --exclude <name>        exclude this Helm release (repeatable)
#   --pattern "<glob>"      uninstall releases that match glob (e.g., "delegate-*")
#   --list                  list target releases and exit
#   --delete-namespace      delete the delegate namespace after uninstall
#
# Common:
#   --namespace <ns>        delegate namespace (default: harness-delegate-ng)
#   --eks-dir <path>        default: aws/eks
#   --irsa-dir <path>       default: aws/iam-irsa
#   --region <r>            AWS region (for kubeconfig update)
#   --cluster-name <n>      EKS cluster name (for kubeconfig update)
#   --yes                   auto-approve (skip confirmations)

set -euo pipefail

say() { printf "\n==> %s\n" "$*"; }
confirm() {
  if [ "${AUTO_APPROVE:-false}" = "true" ]; then return 0; fi
  read -rp "$1 [y/N]: " _ans
  case "$_ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
usage() {
  sed -n '2,200p' "$0" | sed -n '2,80p'
  exit 1
}

# ---------- defaults ----------
DO_DELEGATE=false
DO_PERMISSIONS=false
DO_CLUSTER=false
AUTO_APPROVE="${AUTO_APPROVE:-false}"
KUBECONFIG_UPDATE="${KUBECONFIG_UPDATE:-auto}"

NS="${NS:-harness-delegate-ng}"
EKS_DIR="${EKS_DIR:-aws/eks}"
IRSA_DIR="${IRSA_DIR:-aws/iam-irsa}"

DELEGATE_NAME_FILTER=""
declare -a RELEASES EXCLUDES
PATTERN=""
LIST_ONLY=false
DELETE_NAMESPACE=false

# ---------- arg parsing ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --delegate) DO_DELEGATE=true ;;
    --permissions) DO_PERMISSIONS=true ;;
    --cluster) DO_CLUSTER=true ;;
    --all) DO_DELEGATE=true; DO_PERMISSIONS=true; DO_CLUSTER=true ;;
    --namespace) shift; NS="$1" ;;
    --eks-dir) shift; EKS_DIR="$1" ;;
    --irsa-dir) shift; IRSA_DIR="$1" ;;
    --region) shift; REGION="$1" ;;
    --cluster-name) shift; CLUSTER_NAME="$1" ;;
    --yes) AUTO_APPROVE=true ;;
    --delegate-name) shift; DELEGATE_NAME_FILTER="$1" ;;
    --release) shift; RELEASES+=("$1") ;;
    --exclude) shift; EXCLUDES+=("$1") ;;
    --pattern) shift; PATTERN="$1" ;;
    --list) LIST_ONLY=true ;;
    --delete-namespace) DELETE_NAMESPACE=true ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
  shift || true
done

if ! $DO_DELEGATE && ! $DO_PERMISSIONS && ! $DO_CLUSTER; then
  echo "No actions specified. Use --delegate / --permissions / --cluster / --all"; usage
fi

# ---------- helpers ----------
sanitize_release() {
  echo "$1" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//' \
  | cut -c1-53
}

tf_out() { terraform -chdir="$1" output -raw "$2" 2>/dev/null || true; }

update_kubeconfig() {
  if [ "${KUBECONFIG_UPDATE}" != "auto" ]; then return 0; fi
  local region="${REGION:-}" cluster="${CLUSTER_NAME:-}"

  # Try resolve from TF if not provided
  if [ -z "$cluster" ] && [ -d "$EKS_DIR" ]; then cluster="$(tf_out "$EKS_DIR" cluster_name)"; fi
  if [ -z "$region" ] && [ -d "$EKS_DIR" ]; then region="$(tf_out "$EKS_DIR" region)"; fi

  if [ -n "$cluster" ] && [ -n "$region" ]; then
    say "Updating kubeconfig for cluster '${cluster}' in ${region}"
    aws eks --region "$region" update-kubeconfig --name "$cluster" >/dev/null 2>&1 || true
  else
    say "Skipping kubeconfig update (cluster/region not known)."
  fi
}

# ---------- delegate uninstall ----------
delete_delegate() {
  say "Preparing to uninstall delegate(s) from namespace '${NS}'"
  update_kubeconfig

  if ! kubectl get ns "$NS" >/dev/null 2>&1; then
    say "Namespace '$NS' not found; nothing to do."
    return 0
  fi

  local -a all_releases candidates
  mapfile -t all_releases < <(helm -n "$NS" list --short 2>/dev/null | sed '/^$/d' || true)

  # If a delegate name is supplied, derive its release name directly
  if [ -n "$DELEGATE_NAME_FILTER" ]; then
    local rn; rn="$(sanitize_release "$DELEGATE_NAME_FILTER")"
    if helm -n "$NS" status "$rn" >/dev/null 2>&1; then
      candidates=("$rn")
    else
      say "No Helm release named '$rn' found in ns '$NS' for delegate '$DELEGATE_NAME_FILTER'."
      return 0
    fi
  fi

  # If no delegate name, add any explicitly requested releases
  if [ ${#RELEASES[@]} -gt 0 ]; then
    for r in "${RELEASES[@]}"; do
      if printf '%s\n' "${all_releases[@]}" | grep -qx "$r"; then
        candidates+=("$r")
      else
        say "WARNING: release '$r' not found in ns '$NS'; skipping."
      fi
    done
  fi

  # If still none, detect Harness delegate charted releases
  if [ ${#candidates[@]} -eq 0 ]; then
    for r in "${all_releases[@]}"; do
      if helm -n "$NS" status "$r" 2>/dev/null | grep -qi 'harness-delegate-ng'; then
        candidates+=("$r")
      fi
    done
  fi

  # Apply pattern filter if provided
  if [ -n "$PATTERN" ]; then
    local -a filtered; filtered=()
    for r in "${candidates[@]}"; do
      [[ "$r" == $PATTERN ]] && filtered+=("$r")
    done
    candidates=("${filtered[@]}")
  fi

  # Apply excludes
  if [ ${#EXCLUDES[@]} -gt 0 ]; then
    local -a kept; kept=()
    for r in "${candidates[@]}"; do
      local skip=false
      for x in "${EXCLUDES[@]}"; do
        [[ "$r" == "$x" ]] && { skip=true; break; }
      done
      $skip || kept+=("$r")
    done
    candidates=("${kept[@]}")
  fi

  # De-dup
  if [ ${#candidates[@]} -gt 1 ]; then
    readarray -t candidates < <(printf '%s\n' "${candidates[@]}" | awk '!seen[$0]++')
  fi

  if [ ${#candidates[@]} -eq 0 ]; then
    say "No delegate Helm releases selected in ns '$NS'."
    return 0
  fi

  say "Selected releases in '$NS': ${candidates[*]}"
  $LIST_ONLY && { say "--list requested; exiting."; return 0; }

  confirm "Uninstall the releases above from namespace '$NS'?" || { say "Skipped delegate uninstall."; return 0; }

  for r in "${candidates[@]}"; do
    say "Uninstalling Helm release '$r' (ns=$NS)…"
    helm -n "$NS" uninstall "$r" --wait --timeout 5m || true
  done

  # Upgrader CronJob cleanup (best-effort)
  kubectl -n "$NS" delete cronjob harness-upgrader --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl -n "$NS" delete cronjob -l app=harness-upgrader --ignore-not-found=true >/dev/null 2>&1 || true

  if $DELETE_NAMESPACE; then
    say "Deleting namespace '$NS'…"
    kubectl delete ns "$NS" --wait=true || true
  fi

  say "Delegate uninstall complete."
}

# ---------- terraform destroy helpers ----------
tf_destroy() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    say "Directory '$dir' not found; skipping."
    return 0
  fi
  say "Running 'terraform destroy' in $dir"
  terraform -chdir="$dir" init -upgrade >/dev/null
  if [ "${AUTO_APPROVE}" = "true" ]; then
    terraform -chdir="$dir" destroy -auto-approve
  else
    terraform -chdir="$dir" destroy
  fi
}

# ---------- execute in safe order ----------
$DO_DELEGATE    && delete_delegate
$DO_PERMISSIONS && { say "Destroying IAM/IRSA stack in '$IRSA_DIR'…"; confirm "Proceed?" && tf_destroy "$IRSA_DIR" || say "Skipped permissions destroy."; }
$DO_CLUSTER     && { say "Destroying EKS/VPC stack in '$EKS_DIR'…";   confirm "Proceed? (removes EKS control plane & nodes)" && tf_destroy "$EKS_DIR" || say "Skipped cluster destroy."; }

say "Teardown complete."
