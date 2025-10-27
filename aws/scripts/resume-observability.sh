#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Resuming Grafana and Prometheus…"
terraform apply \
  -var="replica_count=1" \
  -var="grafana_service_type=LoadBalancer" \
  -var="prometheus_replicas=1" \
  -var="alertmanager_replicas=1" \
  -var="kube_state_metrics_enabled=true" \
  -var="node_exporter_enabled=true" \
  -auto-approve

echo "✅ Observability running."
echo "   Grafana: kubectl -n tools get svc -l app.kubernetes.io/name=grafana -o wide"
