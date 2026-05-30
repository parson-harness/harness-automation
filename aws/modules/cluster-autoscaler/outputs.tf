output "release_name" {
  value = helm_release.cluster_autoscaler.name
}

output "namespace" {
  value = helm_release.cluster_autoscaler.namespace
}
