# Harness AWS Automation — EKS + IRSA + Delegate

This repo lets you do **either** of the following, using the same codebase:

- **Create everything**: VPC, EKS, and the IAM role (IRSA) the Harness Delegate uses.
- **Use an existing EKS**: Only create the IAM permissions (IRSA) and then install the Delegate.

Designed for Harness SEs *and* customers. The setup is **decoupled**, so you can run each part independently.

---

## Contents

- [`backend-bootstrap/`](./backend-bootstrap) – one-time S3 + DynamoDB creation for remote Terraform state
- [`eks/`](./eks) – EKS cluster (VPC, EKS, node groups, OIDC outputs)
- [`iam-irsa/`](./iam-irsa) – IAM role & policy for the Harness Delegate via **IRSA**
- [`delegate/`](./delegate) – scripts to **install** and **uninstall** the Delegate
- `tf-init.sh` – initializes **remote state** for the root stack
- `destroy.sh` – decoupled teardown: delegate, permissions, and/or cluster

> **Remote state**: Bootstrap once in `backend-bootstrap/`, then run `./tf-init.sh` in this folder.

---

## Prerequisites

- Terraform **v1.5+**
- AWS CLI configured (`aws sts get-caller-identity` works)
- `kubectl`, `helm`, and `jq`
- IAM permissions to create the resources you choose (S3/Dynamo, EKS, IAM, etc.)

---

## One-time: create the S3 backend

```bash
cd backend-bootstrap
terraform init
terraform apply -auto-approve \
  -var='bucket_name=<globally-unique-s3-bucket>' \
  -var='region=us-east-1' \
  -var='dynamodb_table=terraform-locks'
```

Creates:
- S3 bucket (versioned, encrypted, TLS-only) for **remote state**
- DynamoDB table for **state locking**

---

## Initialize remote state for the root stack

```bash
cd aws
# Set once; both init and apply will reuse them
export TF_VAR_tag_owner="Doe"          # used in names/tags and in the state key
export TF_VAR_region="us-east-1"       # provider region

./tf-init.sh           # uses backend.hcl + computed key
```

Use `./tf-init.sh --migrate` once if moving local → remote state.

---

## Root Variables & Defaults

| Variable | Default | Purpose |
|---|---|---|
| `region` | `us-east-1` | AWS provider region |
| `cluster` | `harness-eks` | Base cluster name (actual: `${cluster}-${tag_owner}`) |
| `tag_owner` | `HarnessPOV` | Suffix for names and the `Owner` tag (set to **your last name**) |
| `instance_type` | `t3.large` | EKS managed node group instance type |
| `delegate_namespace` | `harness-delegate-ng` | K8s namespace for the Delegate |
| `delegate_service_account` | `harness-delegate` | K8s ServiceAccount for the Delegate |
| `artifacts_bucket` | `""` | Optional S3 bucket the Delegate can read/write |
| `ecr_repo_prefix` | `""` | Optional ECR repo prefix for scoping push/pull |
| `assume_role_arns` | `[]` | Optional extra role ARNs the Delegate may assume |
| `create_eks` | `true` | Whether to create a **new** EKS cluster |
| `existing_cluster_name` | `null` | Required if `create_eks=false` |

Effective cluster name: **`${var.cluster}-${var.tag_owner}`**.

---

## Common flows

### A) Provision everything (EKS + IRSA), then install Delegate

```bash
cd aws
terraform apply

# Install delegate via Helm (release name auto = sanitized DELEGATE_NAME)
DELEGATE_NAME="demo-delegate" HARNESS_ACCOUNT_ID="<your-harness-account>" DELEGATE_TOKEN="<a-secure-token>" IRSA_ROLE_ARN="$(terraform output -raw delegate_role_arn)" ./delegate/install_delegate.sh
```

Verify:
```bash
kubectl -n harness-delegate-ng get pods,sa,cronjob
helm -n harness-delegate-ng list
```

### B) Use an existing EKS (IRSA + Delegate only)

```bash
cd aws
terraform apply   -var="create_eks=false"   -var="existing_cluster_name=<your-existing-eks-name>"

DELEGATE_NAME="demo-delegate" HARNESS_ACCOUNT_ID="<your-harness-account>" DELEGATE_TOKEN="<a-secure-token>" ./delegate/install_delegate.sh
```

---

## Uninstall / Destroy

### Remove delegates (Helm)

```bash
# by delegate name (release auto-resolved)
./destroy.sh --delegate --delegate-name demo-delegate --yes

# or list first
./destroy.sh --delegate --list
```

Options: `--release <name>`, `--pattern "glob"`, `--delete-namespace`.

### Decoupled infra teardown

```bash
# IAM/IRSA only
./destroy.sh --permissions --yes

# Cluster (EKS + VPC)
./destroy.sh --cluster --yes

# Everything: delegate -> permissions -> cluster
./destroy.sh --all --yes
```

---

## Troubleshooting

- **Plan errors on data sources**: When creating EKS and IRSA together, the root passes OIDC ARN/issuer to IRSA and sets `resolve_from_cluster=false`. If you changed root wiring, restore that pattern.
- **Remote state**: Re-run `./tf-init.sh --migrate` to move local → S3. Confirm with `terraform state list`.
- **EKS module warning** about `inline_policy` deprecation is upstream; safe to ignore until they update.
