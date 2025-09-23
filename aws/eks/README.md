# EKS Module

Creates VPC, EKS (v1.29 by default), managed node groups, and exposes OIDC outputs for IRSA.

## Inputs (selected)

- `cluster` (default: `harness-eks`) – base name; wrapper appends `-<tag_owner>`
- `tag_owner` (default: `HarnessPOV`) – suffix for names and `Owner` tag
- `instance_type` (default: `t3.large`) – worker nodes
- `delegate_namespace` (default: `harness-delegate-ng`)
- `delegate_service_account` (default: `harness-delegate`)

## Outputs

- `cluster_name`
- `region`
- `oidc_provider_arn`
- `cluster_oidc_issuer_url`

## Usage (from root)

```hcl
module "eks" {
  source = "./eks"
  # vars ...
}
```

> Don’t add a backend block here; backends are configured at the root.
