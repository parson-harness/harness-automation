#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Install kube-prometheus-stack into your "tools" namespace
# and output the Prometheus URL for use in Grafana
# -------------------------------------------------------------------

NAMESPACE="tools"
RELEASE_NAME="monitoring"

echo "🚀 Creating namespace '${NAMESPACE}' (if not exists)..."
kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"

echo "📦 Adding Prometheus Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "🧭 Installing Prometheus stack (Grafana disabled)..."
helm upgrade --install "${RELEASE_NAME}" prometheus-community/kube-prometheus-stack \
  -n "${NAMESPACE}" \
  --set grafana.enabled=false

echo "⏳ Waiting for Prometheus to become ready..."
kubectl -n "${NAMESPACE}" rollout status deploy/${RELEASE_NAME}-kube-prometheus-sta-operator --timeout=5m

# -------------------------------------------------------------------
# Extract Prometheus Service DNS
# -------------------------------------------------------------------
PROM_SVC=$(kubectl -n "${NAMESPACE}" get svc -l "app.kubernetes.io/name=prometheus" \
  -o jsonpath='{.items[0].metadata.name}')

PROM_URL="http://${PROM_SVC}.${NAMESPACE}.svc.cluster.local:9090"
export GRAFANA_PROMETHEUS_URL="${PROM_URL}"

echo ""
echo "✅ Prometheus is installed!"
echo ""
echo "Use this URL in your Grafana Terraform module:"
echo "grafana_prometheus_url = \"${PROM_URL}\""
echo ""
echo "Example reapply:"
echo "terraform apply -var=\"grafana_prometheus_url=${PROM_URL}\""
echo ""
echo "GRAFANA_PROMETHEUS_URL=${GRAFANA_PROMETHEUS_URL}"
echo ""
