#!/usr/bin/env bash
set -euo pipefail

echo "⏳ Spinning down Prometheus stack…"
terraform apply \
  -var="prometheus_replicas=0" \
  -var="alertmanager_replicas=0" \
  -var="kube_state_metrics_enabled=false" \
  -var="node_exporter_enabled=false" \
  -auto-approve

echo "✅ Prometheus paused (no Prom/AM/kube-state-metrics/node-exporter pods). PVCs preserved."
