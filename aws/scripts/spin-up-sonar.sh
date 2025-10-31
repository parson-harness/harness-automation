#!/usr/bin/env bash
# Enable SonarQube via Terraform, then print its External LB endpoint
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TF_DIR="${TF_DIR:-$ROOT_DIR/aws}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"   # set to false to review the plan
KUBECTL="${KUBECTL:-kubectl}"
NAMESPACE="${NAMESPACE:-tools}"        # keep in sync with var.grafana_namespace
SELECTOR="${SELECTOR:-app.kubernetes.io/name=sonarqube}"
SVC_NAME_OVERRIDE="${SVC_NAME_OVERRIDE:-}"  # leave empty to use selector

say()  { printf "\n==> %s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }

cd "$TF_DIR"

say "Enabling SonarQube (TF_VAR_create_sonarqube=true)"
export TF_VAR_create_sonarqube=true

# Optional: set specific chart version via env, e.g. TF_VAR_chart_version="10.5.0+2748"
# export TF_VAR_chart_version="10.5.0+2748"

say "Running terraform init (safe to re-run)"
terraform init -upgrade -input=false

say "Applying Terraform changes"
if [[ "${AUTO_APPROVE}" == "true" ]]; then
  terraform apply -input=false -auto-approve
else
  terraform apply -input=false
fi

say "Waiting for Service external endpoint"
# Try via Terraform outputs first
HOSTNAME="$(terraform output -raw sonarqube_load_balancer_hostname 2>/dev/null || true)"
IP="$(terraform output -raw sonarqube_load_balancer_ip 2>/dev/null || true)"

if [[ -z "${HOSTNAME}" && -z "${IP}" ]]; then
  say "Falling back to kubectl to discover the Service"
  # Use explicit name if provided, else discover by selector
  if [[ -n "$SVC_NAME_OVERRIDE" ]]; then
    $KUBECTL -n "$NAMESPACE" get svc "$SVC_NAME_OVERRIDE" -o wide || true
    HOSTNAME="$($KUBECTL -n "$NAMESPACE" get svc "$SVC_NAME_OVERRIDE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    IP="$($KUBECTL -n "$NAMESPACE" get svc "$SVC_NAME_OVERRIDE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  else
    $KUBECTL -n "$NAMESPACE" get svc -l "$SELECTOR" -o wide || true
    # Assume one matching service (the chart defaults to <release>-sonarqube)
    HOSTNAME="$($KUBECTL -n "$NAMESPACE" get svc -l "$SELECTOR" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    IP="$($KUBECTL -n "$NAMESPACE" get svc -l "$SELECTOR" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  fi
fi

if [[ -n "$HOSTNAME" ]]; then
  say "SonarQube is (likely) reachable at:  http://$HOSTNAME:9000"
elif [[ -n "$IP" ]]; then
  say "SonarQube is (likely) reachable at:  http://$IP:9000"
else
  warn "External endpoint not ready yet. You can watch with:"
  echo "  $KUBECTL -n $NAMESPACE get svc -l $SELECTOR -w"
fi

say "Default auth is often admin/admin unless overridden in chart values."
