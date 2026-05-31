# Delegate Install Helper

This directory contains the Terraform-backed delegate module and the helper script used to install or update a delegate in the AWS workflow.

If you want the conceptual explanation of how the delegate, Harness connectors, IRSA, and OIDC work together, start here:

- [`../../../docs/aws-delegate-access-model.md`](../../../docs/aws-delegate-access-model.md)

## What changed

The install flow is no longer a direct Helm installer.

`install_delegate.sh` now:

- gathers delegate inputs from environment variables or prompts
- reads Terraform outputs when available
- updates kubeconfig for the target EKS cluster
- runs a targeted Terraform plan and apply for the delegate path

## Minimal usage

```bash
cd aws
export HARNESS_ACCOUNT_ID="<your-account-id>"
export DELEGATE_TOKEN="<your-delegate-token>"
export DELEGATE_NAME="demo-delegate"
./modules/delegate/install_delegate.sh
```

## Common optional environment variables

- `NS` - delegate namespace, defaults to `harness-delegate-ng`
- `SA` - delegate service account, defaults to `harness-delegate`
- `REGION` - AWS region if it cannot be read from Terraform outputs
- `CLUSTER_NAME` - EKS cluster name if it cannot be read from Terraform outputs
- `DELEGATE_RELEASE_NAME` - optional Helm release name override
- `MANAGER_ENDPOINT` - delegate manager endpoint, defaults to `https://app.harness.io`
- `DELEGATE_REPLICAS` - number of delegate replicas, defaults to `1`
- `DELEGATE_K8S_PERMISSIONS_TYPE` - defaults to `CLUSTER_ADMIN`
- `DELEGATE_POLL_FOR_TASKS` - set to `true` if polling is required
- `DELEGATE_DESCRIPTION` - optional delegate description
- `DELEGATE_TAGS` - comma-separated delegate tags
- `DELEGATE_IMAGE_TAG` - optional image tag override
- `DELEGATE_UPGRADER_ENABLED` - defaults to `false`
- `DELEGATE_UPGRADER_TOKEN` - optional upgrader token override
- `RUN_TERRAFORM_INIT` - defaults to `true`
- `AUTO_APPROVE` - set to `true` to skip the apply confirmation prompt

## Important usage note

The helper script is convenient for a guided install or update, but future full-stack `terraform apply` runs will only keep managing the delegate if you also persist the delegate variables in `TF_VAR_...` environment variables or an untracked `.tfvars` file.

This repository installs the delegate runtime only. Harness connectors and delegate tokens are still created in Harness.

For ongoing management, prefer the root Terraform variables:

- `create_delegate`
- `delegate_name`
- `delegate_account_id`
- `delegate_token`
- and any optional `delegate_*` variables you need

## Cleanup

For Terraform-managed cleanup:

```bash
terraform destroy -target=module.delegate
```

For release-focused cleanup with the helper script path:

```bash
./destroy.sh --delegate --delegate-name demo-delegate --yes
```
