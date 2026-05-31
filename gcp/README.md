# GCP GKE Example

This directory contains a Terraform example for provisioning a GKE cluster, node pool, VPC, and subnet on GCP.

It is best treated as a cluster provisioning example. Unlike the AWS path, it does not currently include a Terraform-managed Harness delegate workflow.

## What it creates

- a VPC
- a subnet
- a GKE cluster
- a separately managed node pool

## Prerequisites

- Terraform
- Google Cloud SDK
- a GCP project where you can create GKE resources
- authenticated `gcloud` access
- `kubectl`

## Authenticate to GCP

```bash
gcloud init
gcloud auth application-default login
```

To confirm the active project:

```bash
gcloud config get-value project
```

## Configure inputs

Set the required values in `terraform.tfvars` or another `.tfvars` file.

Important variables include:

- `project_id`
- `region`
- `label`
- `gke_num_nodes`
- `machine_type`

## Provision the cluster

```bash
terraform init
terraform plan
terraform apply
```

## Configure `kubectl`

```bash
gcloud container clusters get-credentials \
  $(terraform output -raw kubernetes_cluster_name) \
  --region $(terraform output -raw region)
kubectl get nodes
```

## Optional Kubernetes dashboard steps

If you want a local Kubernetes dashboard for testing:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl proxy
```

## Notes

- This path currently documents GKE provisioning only.
- If you want a Terraform-managed delegate workflow with IRSA/OIDC-style identity wiring, use the AWS path in this repository.
