# IAM IRSA Module (Delegate Role)

Creates an IAM role with a trust policy for EKS **IRSA** and attaches a minimal policy for the Harness Delegate.

## Modes

- **Standalone (existing cluster):** `resolve_from_cluster = true` and set `cluster_name` (module reads cluster to find issuer URL/OIDC provider).
- **Coupled with new EKS:** `resolve_from_cluster = false` and pass `oidc_provider_arn` (and optionally `oidc_issuer_url`) from the EKS outputs.

## Inputs (selected)

- `cluster_name` – required when `resolve_from_cluster=true`
- `namespace` (default: `harness-delegate-ng`)
- `service_account_name` (default: `harness-delegate`)
- `oidc_provider_arn` (default: `null`)
- `oidc_issuer_url` (default: `null`)
- `resolve_from_cluster` (default: `true`)
- `inline_policy_json` – JSON policy for the delegate

## Outputs

- `role_arn` – IAM role ARN for the delegate

## Standalone remote state

```bash
cd aws/iam-irsa
export CLUSTER_NAME="my-eks"
export TF_VAR_tag_owner="Doe"
export TF_VAR_region="us-east-1"
./tf-init.sh
terraform apply -auto-approve -var="cluster_name=${CLUSTER_NAME}"
```

## Teardown
Use the root script for a targeted destroy:
```bash
cd aws
./destroy.sh --permissions --yes
```
