#!/usr/bin/env bash
set -euo pipefail

echo "⏳ Spinning down Grafana..."
echo "Scaling replicas to 0 and converting Service to ClusterIP."

terraform apply \
  -var="create_grafana=true" \
  -var="replica_count=0" \
  -var="grafana_service_type=ClusterIP" \
  -auto-approve

echo "✅ Grafana spun down."
echo "   • Pods stopped"
echo "   • ELB released (ClusterIP only)"
echo "   • Dashboards/config preserved via PVC"
