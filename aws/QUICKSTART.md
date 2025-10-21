# Quickstart — Harness AWS (EKS + IRSA + Delegate)

> **Goal:** Make it crystal clear what to set and what to run.  
> Pick **Path A** (new EKS) or **Path B** (existing EKS). Everything else is optional.

---

## 0) One-time: remote state backend (S3 + DynamoDB)
If not done yet:

```bash
cd aws/modules/backend-bootstrap
terraform init
terraform apply -auto-approve \
  -var='bucket_name=<globally-unique-s3-bucket>' \
  -var='region=us-east-1' \
  -var='dynamodb_table=terraform-locks'
```

Then initialize the root to use that backend:

```bash
cd aws
export TF_VAR_region="us-east-1"        # provider region
export TF_VAR_tag_owner="Parson"           # will suffix resource names/tags
./tf-init.sh
```

---

## Path A — New EKS cluster + IRSA + Delegate

### 1) Terraform
```bash
cd aws
terraform apply
```

### 2) Install Delegate (required vars)
```bash
export HARNESS_ACCOUNT_ID="<your-harness-account>"
export DELEGATE_TOKEN="<your-delegate-token>"     # from Harness UI
export DELEGATE_NAME="demo-delegate"              # unique per namespace
./modules/delegate/install_delegate.sh
```

### 3) Verify
```bash
kubectl -n harness-delegate-ng get pods
helm -n harness-delegate-ng list
```

---

## Path B — Existing EKS cluster + IRSA + Delegate

### 1) Terraform (IRSA only; reuse your cluster)
```bash
cd aws
terraform apply \
  -var="create_eks=false" \
  -var="existing_cluster_name=<your-eks-cluster-name>"
```

### 2) Install Delegate (same as Path A)
```bash
export HARNESS_ACCOUNT_ID="<your-harness-account>"
export DELEGATE_TOKEN="<your-delegate-token>"
export DELEGATE_NAME="demo-delegate"
./modules/delegate/install_delegate.sh
```

---

## Swap / Reinstall a Delegate (keep cluster + IRSA)

```bash
cd aws
./destroy.sh --delegate --delegate-name demo-delegate --yes

export HARNESS_ACCOUNT_ID="..."
export DELEGATE_TOKEN="..."
export DELEGATE_NAME="demo-delegate"
./modules/delegate/install_delegate.sh
```

---

## Clean up (optional)

- **Delegate only:**  
  `./destroy.sh --delegate --delegate-name demo-delegate --yes`

- **Permissions (IRSA) only:**  
  `./destroy.sh --permissions --yes`

- **Cluster (EKS + VPC) only:**  
  `./destroy.sh --cluster --yes`

- **Everything:**  
  `./destroy.sh --all --yes`

---

## Variables you typically set

### Terraform (root)
- `TF_VAR_region` — AWS region (e.g., `us-east-1`)
- `TF_VAR_tag_owner` — your surname or unique tag (used in names/tags)
- Optional:
  - `-var="create_eks=false"` and `-var="existing_cluster_name=<cluster>"` for Path B

### Delegate install (script reads some from TF outputs)
- **Required:**  
  `HARNESS_ACCOUNT_ID`, `DELEGATE_TOKEN`, `DELEGATE_NAME`
- **Common optional:**  
  `NS` (default `harness-delegate-ng`), `SA` (default `harness-delegate`),  
  `REGION`, `CLUSTER_NAME` (if your kube context isn’t set),  
  `IRSA_ROLE_ARN` (auto-read from outputs if present),  
  `DELEGATE_REPLICAS` (default `1`).

> The script automatically resolves the **latest** `harness/delegate` image tag from Docker Hub.  
> To pin an image: `export DELEGATE_IMAGE="us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:<tag>"`

---

## Script flags & knobs (cheatsheet)

### `modules/delegate/install_delegate.sh` (env-driven)
- **Required:** `HARNESS_ACCOUNT_ID`, `DELEGATE_TOKEN`, `DELEGATE_NAME`
- **Optional:**  
  `NS`, `SA`, `REGION`, `CLUSTER_NAME`, `DELEGATE_REPLICAS`,  
  `MANAGER_ENDPOINT` (default `https://app.harness.io/gratis`),  
  `IRSA_ROLE_ARN` (auto from TF outputs if present),  
  `DELEGATE_IMAGE` or `DELEGATE_IMAGE_PREFIX`,  
  `KUBECONFIG_UPDATE=auto|skip`, `CONTEXT_NAME`.

### `destroy.sh` (flags)
- **Delegate uninstall:**  
  `--delegate --delegate-name <name>` (maps to Helm release)  
  or `--release <helm-release>` or `--pattern "glob"`  
  Extras: `--list`, `--delete-namespace`, `--ns <namespace>`
- **Infra:** `--permissions`, `--cluster`, or `--all`
- **General:** `--region`, `--cluster-name`, `--yes`

---

## Notes

- Nodegroups default to **`AL2023_x86_64`** to support newer Kubernetes versions.
- Names/tags include `tag_owner` for easier tracking in AWS.
