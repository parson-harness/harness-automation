# AWS Quickstart

This is the shortest path to a working AWS sandbox environment in this repository.

## 0) Create the remote state backend once

```bash
cd aws/modules/backend-bootstrap
terraform init
terraform apply -auto-approve \
  -var='bucket_name=<globally-unique-s3-bucket>' \
  -var='region=us-east-1' \
  -var='dynamodb_table=terraform-locks'
```

## 1) Initialize the AWS root stack

```bash
cd aws
export TF_VAR_region="us-east-1"
export TF_VAR_tag_owner="Doe"
./tf-init.sh
```

## 2) Provision infrastructure

### New EKS cluster

```bash
terraform apply
```

### Existing EKS cluster

```bash
terraform apply \
  -var="create_eks=false" \
  -var="existing_cluster_name=<your-eks-cluster-name>"
```

## 3) Install a delegate

### Fastest guided path

```bash
export HARNESS_ACCOUNT_ID="<your-account-id>"
export DELEGATE_TOKEN="<your-delegate-token>"
export DELEGATE_NAME="demo-delegate"
./modules/delegate/install_delegate.sh
```

### Best path for ongoing Terraform management

If you want future `terraform apply` runs to continue managing the delegate, persist these settings in environment variables or an untracked `.tfvars` file:

```bash
export TF_VAR_create_delegate=true
export TF_VAR_delegate_name="demo-delegate"
export TF_VAR_delegate_account_id="<your-account-id>"
export TF_VAR_delegate_token="<your-delegate-token>"
terraform apply
```

## 4) Verify

```bash
kubectl -n harness-delegate-ng get pods
terraform output delegate_release_name
terraform output delegate_image_tag
```

## 5) Clean up

### Delegate only

```bash
terraform destroy -target=module.delegate
```

### IRSA only

```bash
./destroy.sh --permissions --yes
```

### Cluster only

```bash
./destroy.sh --cluster --yes
```

### Everything

```bash
./destroy.sh --all --yes
```

## Notes

- Save delegate-related Terraform inputs if you want later full applies to keep the delegate installed.
- Verify your AWS session before starting with `aws sts get-caller-identity`.
- Names and tags include `tag_owner` so multiple users can share the same AWS account more safely.
