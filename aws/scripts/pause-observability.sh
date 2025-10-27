#!/usr/bin/env bash
set -euo pipefail

echo "⏳ Pausing Grafana and Prometheus…"
terraform apply \
  -var="replica_count=0" \
  -var="grafana_service_type=ClusterIP" \
  -var="prometheus_replicas=0" \
  -var="alertmanager_replicas=0" \
  -var="kube_state_metrics_enabled=false" \
  -var="node_exporter_enabled=false" \
  -auto-approve

echo "✅ Observability paused."
