# EKS POV Cluster + Harness Delegate (Terraform + Helm)

This repo spins up an **EKS cluster** for Harness Runners and installs a **Harness Kubernetes Delegate** with **IRSA**. It’s optimized for quick spin-up/tear-down, sane defaults, and a one-command delegate install.

---

## What you get

- VPC (public + private subnets), IGW, optional NAT (public node groups by default to avoid NAT/EIP limits)
- EKS cluster (1.29), two managed node groups (public subnets)
- IRSA role for the Harness delegate with practical permissions:
  - ECR push/pull (optionally scope to a repo prefix)
  - ECS deploy actions with constrained `iam:PassRole` (`harness-ecs-*`)
  - Utility read-only (EC2/EKS/ELB/ASG/CloudFormation) + CloudWatch Logs write
  - Optional S3 bucket read/write (when `artifacts_bucket` set)
  - Optional cross-account `sts:AssumeRole` (when `assume_role_arns` set)
- Terraform-managed **Namespace** and **ServiceAccount** for the delegate
- A helper script to install/upgrade the delegate via Helm

---

## Prerequisites

- Terraform ≥ 1.5
- AWS CLI configured with a role that can create EKS/VPC/IAM
- `kubectl` and `helm` on your PATH
- `curl` (and **optional `jq`** for nicer JSON parsing)
- Harness **Account ID** and a **Delegate Token** (generated in the UI)

> Examples assume **us-east-1**, but you can set any region via variables.

---

## Quick start

### 1) Configure variables
Edit `variables.tf` or pass at apply time.

- `cluster` (default: `parson-eks`)
- `region` (default: `us-east-1`)
- `tag_owner` (e.g., `parson`)
- `instance_type` (default: `t3.large`)
- `delegate_namespace` (default: `harness-delegate-ng`)
- `delegate_service_account` (default: `harness-delegate`)
- Optional:
  - `ecr_repo_prefix` to scope ECR push/pull (else all repos)
  - `artifacts_bucket` to enable S3 RW
  - `assume_role_arns` (list of ARNs) to allow cross-account assumes

### 2) Provision

```bash
terraform init
terraform apply -auto-approve
```

On success you’ll see outputs like:

- `delegate_role_arn`
- `delegate_service_account_annotation`

### 3) Get a Delegate Token

In Harness UI → **Account Settings → Delegates → Add new delegate → Kubernetes → Helm Chart**. Note the **Account ID** and **Delegate Token**.

### 4) Install the delegate

Use the helper script (idempotent). It reuses the TF namespace/SA and patches **IRSA** if needed.

```bash
export HARNESS_ACCOUNT_ID="<your_account_id>"
export DELEGATE_TOKEN="<delegate_token>"
scripts/install_delegate.sh
```

The script will:
- Resolve the **latest stable** delegate image tag (from Docker Hub), or optionally from the Harness API if you set `HARNESS_API_KEY`
- Annotate the ServiceAccount with the IRSA role (`eks.amazonaws.com/role-arn`)
- Grant cluster-admin via a **ClusterRoleBinding** (can be disabled with `DELEGATE_CLUSTER_ADMIN=false`)
- `helm upgrade -i` the chart **harness-delegate/harness-delegate-ng**
- Wait for the deployment and run an IRSA smoke test job (`aws sts get-caller-identity`)

---

## Script options (env vars)

- **Required**
  - `HARNESS_ACCOUNT_ID` – your account identifier
  - `DELEGATE_TOKEN` – token from the UI
- **Common**
  - `MANAGER_ENDPOINT` – default `https://app.harness.io`
  - `DELEGATE_IMAGE_PREFIX` – default `us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate`; set to `harness/delegate` to pull from Docker Hub
  - `DELEGATE_REPLICAS` – default `1`
  - `DELEGATE_CLUSTER_ADMIN` – default `true` (set `false` to skip cluster-admin binding)
  - `IRSA_SMOKETEST` – default `true`
- **Advanced**
  - `HARNESS_API_KEY` – if set, script will use the Harness API to fetch the version used in the account associated with the API key
  - `HARNESS_API_BASE` – default `https://app.harness.io` (or `https://app.eu.harness.io`)
  - `DELEGATE_IMAGE` – bypass auto-resolution and force an image (e.g., `harness/delegate:25.08.86600`)

---

## How IRSA & policies work here

Terraform creates an OIDC-bound role for the delegate SA and attaches “buckets” of managed inline policies:

- **ECR**: auth + push/pull; optionally constrained by `ecr_repo_prefix`
- **ECS**: describe/list + (de)register task defs; create/update/delete services; `iam:PassRole` restricted to `arn:aws:iam::<acct>:role/harness-ecs-*` with `iam:PassedToService=ecs-tasks.amazonaws.com`
- **Utility**: read-only describes across EC2/EKS/ELB/ASG/CloudFormation + CloudWatch Logs write
- **S3 (optional)**: list bucket + RW objects for `artifacts_bucket`
- **STS (optional)**: `sts:AssumeRole` to each ARN in `assume_role_arns`

This gives a practical, not-wide-open access for POCs. Tighten further if needed.

---

## Troubleshooting

### Helm: `context deadline exceeded`
Helm waited 5 minutes and the deployment never became Ready. Find why:

```bash
NS="harness-delegate-ng"
NAME="$(terraform output -raw cluster_name 2>/dev/null || echo parson-eks)-delegate"

kubectl -n "$NS" get deploy,rs,po -o wide
kubectl -n "$NS" describe deploy "$NAME" | sed -n '1,160p'
kubectl -n "$NS" get events --sort-by=.metadata.creationTimestamp | tail -n 120

POD="$(kubectl -n "$NS" get po -l app.kubernetes.io/instance=helm-delegate -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [ -n "$POD" ]; then
  kubectl -n "$NS" describe pod "$POD" | sed -n '1,200p'
  kubectl -n "$NS" logs "$POD" --container delegate --tail=200 || true
fi
```

Common causes & quick fixes:
- **`ImagePullBackOff`** → egress/registry issue. Set `DELEGATE_IMAGE_PREFIX=harness/delegate` (Docker Hub) and retry. Increase wait: `--timeout 10m`.
- **`Pending` (no nodes / taints / resources)** → lower requests and retry:
  ```bash
  helm upgrade helm-delegate -n "$NS" harness-delegate/harness-delegate-ng --reuse-values     --set resources.requests.cpu=100m --set resources.requests.memory=256Mi     --set resources.limits.cpu=500m --set resources.limits.memory=1Gi     --wait --timeout 10m
  ```
- **`CrashLoopBackOff`** or **not Ready** but Running:
  - Invalid token → issue a new token in UI and `--set-string delegateToken="$NEW_TOKEN"`
  - Wrong endpoint → for free/community, use `MANAGER_ENDPOINT=https://app.harness.io/gratis`
  - DNS/egress blocked to `app.harness.io` → verify with a busybox/curl test from a pod

### EKS nodes can’t reach the internet
If you place nodes in **private subnets**, you must have a working **NAT Gateway + EIP quota**. For POVs, this repo uses **public subnets for node groups** to avoid NAT/EIP quota issues.

---

## Uninstall / Destroy

### Uninstall the delegate (keep cluster)
```bash
helm uninstall helm-delegate -n harness-delegate-ng || true
kubectl delete clusterrolebinding harness-delegate-admin || true
```

### Destroy all infra
```bash
terraform destroy
```

If node groups hang on destroy:
1. Scale desired to 0 in the AWS Console or via CLI for the ASG(s)
2. Delete stuck node groups with `aws eks delete-nodegroup ...`
3. Re-run `terraform destroy`

---

## Variables (high-level)

- `cluster` (string) – cluster name
- `region` (string)
- `tag_owner` (string) – tag for ownership
- `instance_type` (string) – node type for managed node groups
- `delegate_namespace` (string) – default `harness-delegate-ng`
- `delegate_service_account` (string) – default `harness-delegate`
- `ecr_repo_prefix` (string, optional) – scope ECR RW
- `artifacts_bucket` (string, optional) – enable S3 RW
- `assume_role_arns` (list(string), optional) – allow cross-account

## Outputs

- `cluster_name`, `region`
- `delegate_role_arn`
- `delegate_service_account_annotation`

---

## Notes

- We rely on **name_prefix** for IAM policies to avoid collisions across POV runs.
- The delegate auto-upgrader may roll to the account’s published version later; the install script only chooses a good initial image.
- For EU accounts, set `MANAGER_ENDPOINT=https://app.eu.harness.io`.

---

Happy shipping! 🚀