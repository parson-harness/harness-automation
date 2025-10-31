#!/usr/bin/env bash
# Disable SonarQube via Terraform. Optional PVC cleanup.
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TF_DIR="${TF_DIR:-$ROOT_DIR/aws}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"
KUBECTL="${KUBECTL:-kubectl}"
NAMESPACE="${NAMESPACE:-tools}"
SELECTOR="${SELECTOR:-app.kubernetes.io/name=sonarqube}"
DELETE_PVC="${DELETE_PVC:-false}"  # set true to remove persisted data

say()  { printf "\n==> %s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }

cd "$TF_DIR"

say "Disabling SonarQube (TF_VAR_create_sonarqube=false)"
export TF_VAR_create_sonarqube=false

say "Applying Terraform changes"
if [[ "${AUTO_APPROVE}" == "true" ]]; then
  terraform apply -input=false -auto-approve
else
  terraform apply -input=false
fi

if [[ "$DELETE_PVC" == "true" ]]; then
  say "Deleting SonarQube PVCs (this removes persisted data)"
  # Best-effort: delete any PVCs in the namespace that match selector
  # The chart typically names claims with the release prefix (e.g., sonarqube-sonarqube)
  $KUBECTL -n "$NAMESPACE" get pvc -o name | grep -Ei 'sonarqube' | xargs -r $KUBECTL -n "$NAMESPACE" delete
else
  warn "PVCs likely remain (data preserved). Set DELETE_PVC=true to remove them."
fi
