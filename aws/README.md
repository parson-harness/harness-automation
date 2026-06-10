# AWS Sandbox Automation

This directory contains the Terraform configuration and helper scripts for building an AWS-based Kubernetes sandbox environment.

It supports two common starting points:

- provision a new EKS cluster and supporting AWS resources
- connect to an existing EKS cluster and add the IAM and delegate pieces you need

The AWS path is intended to be useful for internal demos, workshops, proof-of-concept environments, and customer-owned sandboxes.

## What gets managed here

Depending on which variables you enable, this stack can manage:

- a VPC and EKS cluster
- IAM roles for Kubernetes service accounts through IRSA
- a Terraform-managed delegate Helm release
- supporting platform components such as ingress, cert-manager, observability components, and optional add-ons

## Repository contents

- `modules/backend-bootstrap/` - one-time S3 and DynamoDB setup for remote Terraform state
- `modules/eks/` - VPC, EKS, and node group provisioning
- `modules/iam-irsa/` - IAM role creation for Kubernetes service accounts
- `modules/delegate/` - Terraform-backed delegate installation helper and module inputs
- `tf-init.sh` - initializes the root stack to use the remote backend
- `destroy.sh` - helper for delegate cleanup and selective infrastructure teardown
- `QUICKSTART.md` - shortest path to a working environment

## Architecture reference

If you want the conceptual model behind the AWS setup, start here before going deeper into the operational steps:

- [`../docs/aws-delegate-access-model.md`](../docs/aws-delegate-access-model.md)

## Prerequisites

- Terraform `1.5+`
- AWS CLI authenticated to the target account
- `kubectl`
- `python3`
- `helm` if you plan to inspect or clean up Helm releases with local commands or `destroy.sh`
- permissions to create the AWS and Kubernetes resources you choose to enable

Verify your AWS session before you begin:

```bash
aws sts get-caller-identity
```

## One-time backend bootstrap

If you have not already created a remote state backend for this stack:

```bash
cd aws/modules/backend-bootstrap
terraform init
terraform apply -auto-approve \
  -var='bucket_name=<globally-unique-s3-bucket>' \
  -var='region=us-east-1' \
  -var='dynamodb_table=terraform-locks'
```

This creates:

- an S3 bucket for Terraform state
- a DynamoDB table for state locking

## Initialize the root stack

```bash
cd aws
export TF_VAR_region="us-east-1"
export TF_VAR_tag_owner="Doe"
./tf-init.sh
```

`tag_owner` is used in names and tags so multiple users can share the same AWS account more safely.

## Choose a deployment mode

### Option A: create a new EKS cluster

```bash
cd aws
terraform apply
```

When this stack creates EKS, baseline worker capacity is controlled by the warm-node settings:

- `warm_az` selects which Availability Zone keeps baseline nodes running
- `warm_desired` sets how many baseline nodes stay warm in that AZ
- `max_size` sets the per-node-group scale-up ceiling
- if `warm_az` is unset, the per-AZ node groups start with zero desired nodes

### Option B: reuse an existing EKS cluster

```bash
cd aws
terraform apply \
  -var="create_eks=false" \
  -var="existing_cluster_name=<your-eks-cluster-name>"
```

## Install a delegate

There are two good ways to manage the delegate.

### Recommended for ongoing Terraform management

Persist your delegate settings in environment variables or an untracked `.tfvars` file, then run `terraform apply` normally.

Example using environment variables:

```bash
export TF_VAR_create_delegate=true
export TF_VAR_delegate_name="demo-delegate"
export TF_VAR_delegate_account_id="<your-account-id>"
export TF_VAR_delegate_token="<your-delegate-token>"
terraform apply
```

Optional variables you may want to set include:

- `TF_VAR_delegate_release_name`
- `TF_VAR_delegate_replicas`
- `TF_VAR_delegate_manager_endpoint`
- `TF_VAR_delegate_k8s_permissions_type`
- `TF_VAR_delegate_tags`
- `TF_VAR_delegate_image_tag`
- `TF_VAR_delegate_upgrader_enabled`

This is the best option if you expect future `terraform apply` runs to keep managing the delegate.

### Guided install helper

If you want an interactive helper, use:

```bash
cd aws
export HARNESS_ACCOUNT_ID="<your-account-id>"
export DELEGATE_TOKEN="<your-delegate-token>"
export DELEGATE_NAME="demo-delegate"
./modules/delegate/install_delegate.sh
```

The script now wraps Terraform rather than calling Helm directly. It can:

- read cluster name and region from Terraform outputs when available
- update kubeconfig for the target EKS cluster
- run a targeted delegate plan and apply
- prompt for missing delegate inputs

If you use the helper script and want later full-stack `terraform apply` runs to continue managing the delegate, save the same delegate settings in `TF_VAR_...` environment variables or an untracked `.tfvars` file afterward.

## Verify the environment

```bash
kubectl -n harness-delegate-ng get pods,sa,secrets
terraform output delegate_release_name
terraform output delegate_image_tag
```

If you are using a different namespace or release name, substitute those values.

## Cleanup options

### Remove the delegate while keeping the cluster

If the delegate is managed through normal Terraform variables, use one of these approaches:

```bash
terraform destroy -target=module.delegate
```

or set:

```hcl
create_delegate = false
```

and run:

```bash
terraform apply
```

### Clean up a delegate release with the helper script

For Helm-release-focused cleanup or recovery work:

```bash
./destroy.sh --delegate --delegate-name demo-delegate --yes
```

### Remove IRSA only

```bash
./destroy.sh --permissions --yes
```

### Remove the EKS cluster and VPC

```bash
./destroy.sh --cluster --yes
```

### Remove everything

```bash
./destroy.sh --all --yes
```

## Troubleshooting

- **AWS auth expired**
  - Re-authenticate before `terraform init`, `plan`, or `apply`.
  - Verify with `aws sts get-caller-identity`.

- **Delegate disappears on a later full `terraform apply`**
  - Make sure `create_delegate` and the delegate inputs are persisted in `TF_VAR_...` environment variables or an untracked `.tfvars` file.
  - The guided helper script is convenient for first install, but ongoing management should use saved Terraform inputs.

- **Existing cluster mode fails**
  - Confirm the AWS identity you are using can describe the cluster and update kubeconfig.
  - Confirm your local Kubernetes access is authorized for that cluster.

## Fastest path

If you just want the shortest first-run checklist, see [`QUICKSTART.md`](./QUICKSTART.md).
