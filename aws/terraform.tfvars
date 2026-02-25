# aws/terraform.tfvars
############################
# Platform / EKS
############################
region                = "us-east-1"
create_eks            = true
existing_cluster_name = "harness-eks-parson" # set when create_eks = false: "my-existing-eks" otherwise set when create_eks = true: null
warm_az               = "us-east-1a"
warm_desired          = 1

cluster       = "harness-eks"
tag_owner     = "parson"

# Bump up for a large workshop
instance_type = "t3.xlarge"
min_size      = 1

# Bump up for a large workshop
desired_size  = 2
max_size      = 4

# storage class
create_default_storage_class = true
storage_class_name           = "gp3"
storage_class_volume_type    = "gp3"

# Harness delegate bits (optional)
delegate_namespace       = "harness-delegate-ng"
delegate_service_account = "parson-eks-delegate"

# Optional AWS integrations for delegate
artifacts_bucket = ""
ecr_repo_prefix  = ""
assume_role_arns = []

############################
# Grafana (optional)
############################
create_grafana    = true
grafana_namespace = "tools"
grafana_release   = "grafana"
# grafana_service_type = "LoadBalancer"
grafana_storage_size = "5Gi"
grafana_admin_user   = "admin"
grafana_admin_pass   = "HarnessFTW!"
replica_count        = 0
grafana_service_type = "ClusterIP"
grafana_host         = ""
#grafana_acm_cert_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxx-xxxx-xxxx"
acme_email = "todd.parson@harness.io"


# Optional: auto-import dashboards (examples commented)
grafana_dashboards = [
  { gnet_id = 11378, revision = 9, datasource = "Prometheus" },
  { gnet_id = 4701, revision = 7, datasource = "Prometheus" }
]

############################
# Prometheus (optional)
############################
prometheus_replicas        = 1
alertmanager_replicas      = 1
kube_state_metrics_enabled = true
node_exporter_enabled      = true

############################
# Sonarqube (optional)
############################
create_sonarqube = true # set false to de-provision on next apply
