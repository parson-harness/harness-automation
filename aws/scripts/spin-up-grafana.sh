#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Spinning up Grafana..."
echo "Scaling replicas to 1 and restoring LoadBalancer Service."

terraform apply \
  -var="create_grafana=true" \
  -var="replica_count=1" \
  -var="grafana_service_type=LoadBalancer" \
  -auto-approve

echo "✅ Grafana is running again."
echo "   Check status:"
echo "     kubectl -n tools get pods,svc | grep grafana"
echo ""
echo "   Login command (from outputs):"
echo "     terraform output -raw admin_password_cmd"
