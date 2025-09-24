# Harness AWS Automation — EKS + IRSA + Delegate

This repo lets you do **either** of the following, using the same codebase:

- **Create everything**: VPC, EKS, and the IAM role (IRSA) the Harness Delegate uses.
- **Use an existing EKS**: Only create the IAM permissions (IRSA) and then install the Delegate.

Designed for Harness SEs *and* customers. The setup is **decoupled**, so you can run each part independently.

---

## What changed recently (2025-09-23)

- **Delegate install is sturdier:** the script now:
  - uses the **official Helm repo** alias `harness-delegate` and chart `harness-delegate/harness-delegate-ng`,
  - **dynamically resolves the latest** `harness/delegate` image tag from Docker Hub (Harness API fallback),
  - writes a **temporary `values.yaml`** so everything is properly **quoted** (fixes YAML parse errors and invalid image names),
  - maps **`DELEGATE_NAME → Helm release` 1:1**, so multiple delegates per cluster work cleanly.
- **Destroy script is macOS-safe** (Bash 3.2 compatible) and can uninstall a delegate by **name** without touching IRSA/cluster.
- **EKS nodegroups use `AL2023_x86_64`** by default to avoid AL2 incompatibility on newer Kubernetes.

---

## Contents

- [`backend-bootstrap/`](./backend-bootstrap) – one-time S3 + DynamoDB creation for remote Terraform state
- [`eks/`](./eks) – EKS cluster (VPC, EKS, node groups, OIDC outputs)
- [`iam-irsa/`](./iam-irsa) – IAM role & policy for the Harness Delegate via **IRSA**
- [`delegate/`](./delegate) – scripts to **install** and **uninstall** the Delegate
- `tf-init.sh` – initializes **remote state** for the root stack
- `destroy.sh` – decoupled teardown: delegate, permissions, and/or cluster (mac-safe)

> **Remote state**: Bootstrap once in `backend-bootstrap/`, then run `./tf-init.sh` in this folder.

---

## Prerequisites

- Terraform **v1.5+**
- AWS CLI configured (`aws sts get-caller-identity` works)
- `kubectl`, `helm`, and `jq` (jq optional but speeds up tag resolution)
- `curl` (used to resolve the latest delegate image tag)
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

# Install delegate (latest image auto-resolved; IRSA auto read from TF outputs if present)
export HARNESS_ACCOUNT_ID="<your-harness-account>"
export DELEGATE_TOKEN="<a-secure-token>"
export DELEGATE_NAME="demo-delegate"
./delegate/install_delegate.sh
```

Verify:
```bash
kubectl -n harness-delegate-ng get pods,sa,cronjob
helm -n harness-delegate-ng list
```

### B) Use an existing EKS (IRSA + Delegate only)

```bash
cd aws
terraform apply \
  -var="create_eks=false" \
  -var="existing_cluster_name=<your-existing-eks-name>"

export HARNESS_ACCOUNT_ID="<your-harness-account>"
export DELEGATE_TOKEN="<a-secure-token>"
export DELEGATE_NAME="demo-delegate"
./delegate/install_delegate.sh
```

---

## Uninstall / Destroy

### Remove delegates (Helm)

```bash
# by delegate name (release auto-resolved 1:1)
./destroy.sh --delegate --delegate-name demo-delegate --yes

# or preview first
./destroy.sh --delegate --pattern "demo-*" --list
```

Options: `--release <name>`, `--pattern "glob"`, `--delete-namespace`.

### Decoupled infra teardown (optional)

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

- **YAML parse error / invalid image name** during Helm install:
  - The installer now generates a **temp values.yaml** and quotes all strings.
  - It also prints progress to **stderr** and only the final image value to **stdout**, so Helm never receives logging noise as a value.

- **Plan errors on data sources**: When creating EKS and IRSA together, the root passes OIDC ARN/issuer to IRSA and sets `resolve_from_cluster=false`.

- **Nodegroup error “AL2_x86_64 is only supported for versions ≤ 1.32”**:
  - Nodegroups default to `AL2023_x86_64`. If you forked earlier code, update `eks_managed_node_group_defaults.ami_type`.

---

## Notes

- Names and tags include your `tag_owner` so resources are easy to find in the AWS account.
- Backends are **configured at init time** (variables are not available to backend configs), so use `tf-init.sh`.

---
> **Quickstart added (2025-09-23)**  
See [`QUICKSTART.md`](./QUICKSTART.md) for the fastest end-to-end path, including the exact env vars and commands to run.
