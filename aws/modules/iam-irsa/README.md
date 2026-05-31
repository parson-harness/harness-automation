# IAM IRSA Module

This module creates the IAM role used by a Kubernetes service account through IRSA.

In the AWS workflow in this repository, that role is typically used by the Harness delegate.

If you want the full conceptual explanation of delegate access, connectors, IRSA, and OIDC, start here:

- [`../../../docs/aws-delegate-access-model.md`](../../../docs/aws-delegate-access-model.md)

## What this module does

- resolves or accepts the cluster OIDC details
- creates an IAM trust policy for a Kubernetes service account
- creates an IAM role for that trust policy
- attaches the provided IAM policy JSON to that role

## Two operating modes

### Existing cluster mode

Use this when the EKS cluster already exists.

- set `resolve_from_cluster = true`
- set `cluster_name`
- the module reads the cluster and looks up the OIDC provider automatically

### Same-apply mode

Use this when Terraform is creating EKS in the same root stack.

- set `resolve_from_cluster = false`
- pass `oidc_provider_arn`
- optionally pass `oidc_issuer_url`

This avoids trying to rediscover OIDC details from a cluster that is still being created.

## Important inputs

- `cluster_name` - required when `resolve_from_cluster = true`
- `namespace` - Kubernetes namespace for the service account
- `service_account_name` - Kubernetes service account name
- `oidc_provider_arn` - OIDC provider ARN when wiring from a newly created EKS cluster
- `oidc_issuer_url` - OIDC issuer URL when you want to pass it explicitly
- `resolve_from_cluster` - chooses between discovery mode and passed-in mode
- `allow_all_delegate_namespaces` - broadens the trust policy to `harness-delegate-*` namespaces
- `inline_policy_json` - IAM policy JSON to attach to the role

## Output

- `role_arn` - IAM role ARN to annotate on the Kubernetes service account

## Typical root usage

This module is normally consumed from the AWS root stack, not run on its own.

The root stack then passes the resulting `role_arn` into the delegate module so the delegate service account can use IRSA.

## Cleanup

Use the root helper for a targeted cleanup:

```bash
cd aws
./destroy.sh --permissions --yes
```
