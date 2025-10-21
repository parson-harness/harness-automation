# aws/modules/prometheus/outputs.tf
output "prometheus_url" {
  description = "Cluster-internal Prometheus base URL for Grafana datasource"
  value       = "http://${kubernetes_service_v1.prometheus_incluster.metadata[0].name}.${var.namespace}.svc.cluster.local:9090"
}

