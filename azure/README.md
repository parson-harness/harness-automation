# Azure AKS Example

This directory contains a simple Terraform example for provisioning an AKS cluster and its resource group.

It is intentionally lightweight and is best treated as a cluster provisioning example, not a full platform stack like the AWS path.

## What it creates

- an Azure resource group
- an AKS cluster with a system-assigned identity
- a default node pool
- generated names based on `random_pet` so repeated runs are less likely to collide

## Prerequisites

- Terraform
- Azure CLI
- `kubectl`
- access to an Azure subscription where you can create AKS resources

## Authenticate to Azure

```bash
az login
az account show
az account set --subscription "<subscription_id_or_subscription_name>"
```

## Configure inputs

Important variables include:

- `resource_group_location` - defaults to `centralus`
- `resource_group_name_prefix` - defaults to `harness-poc-rg`
- `node_count` - defaults to `2`
- `username` - admin username for the cluster nodes

## Provision the cluster

```bash
terraform init -upgrade
terraform plan -out main.tfplan
terraform apply main.tfplan
```

## Verify the result

```bash
resource_group_name=$(terraform output -raw resource_group_name)
az aks list --resource-group "$resource_group_name" --query "[].{name:name}" --output table
```

## Configure `kubectl`

This example exposes the raw kubeconfig as a Terraform output.

```bash
terraform output -raw kube_config > ./azurek8s
export KUBECONFIG=./azurek8s
kubectl get nodes
```

## Notes

- This path currently focuses on AKS provisioning only.
- If you want the most complete sandbox workflow in this repository, use the AWS path.
