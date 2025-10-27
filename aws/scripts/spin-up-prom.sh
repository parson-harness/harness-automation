#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Spinning up Prometheus stack…"
terraform apply \
  -var="prometheus_replicas=1" \
  -var="alertmanager_replicas=1" \
  -var="kube_state_metrics_enabled=true" \
  -var="node_exporter_enabled=true" \
  -auto-approve

echo "✅ Prometheus running. Check:"
echo "   kubectl -n tools get sts,deploy,ds | egrep -i 'prometheus|alertmanager|kube-state|node-exporter'"
