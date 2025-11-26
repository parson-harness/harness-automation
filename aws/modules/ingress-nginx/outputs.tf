# aws/ingress-nginx/outputs.tf
output "namespace" { value = var.namespace }
output "release_name" { value = var.release_name }
output "lb_hostname" { value = local.lb_hostname }
output "lb_ip" { value = local.lb_ip }
output "suggested_sslip" {
  description = "Convenience FQDN for demos when you don’t own DNS"
  value       = local.sslip_host
}
