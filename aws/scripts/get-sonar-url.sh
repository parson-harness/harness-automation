# scripts/print-sonarqube-url.sh
#!/usr/bin/env bash
set -euo pipefail
NS="${NS:-tools}"
host="$(kubectl -n "$NS" get svc -l app.kubernetes.io/name=sonarqube -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
ip="$(kubectl -n "$NS" get svc -l app.kubernetes.io/name=sonarqube -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
if [[ -n "$host" ]]; then echo "http://$host:9000"; elif [[ -n "$ip" ]]; then echo "http://$ip:9000"; else echo "LB not ready"; fi
