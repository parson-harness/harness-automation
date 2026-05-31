# Harness Automation

Terraform-based infrastructure automation for standing up sandbox, workshop, and evaluation environments across AWS, Azure, and GCP.

This repository is designed to be practical and reusable. You can use it internally with teammates, or share it with customers and prospects who want a starting point for their own cloud sandbox environments.

## What this repository includes

- Reusable cloud-specific Terraform configurations
- Kubernetes-oriented sandbox environments
- Optional delegate installation where supported by that cloud path
- Helper scripts for common setup and teardown workflows

## Repository layout

- `aws/` - the most complete path in this repository, including EKS, IAM/IRSA, optional delegate management, and supporting platform components
- `azure/` - an AKS example environment
- `gcp/` - a GKE example environment
- `docs/` - conceptual and architecture-focused documentation

## Recommended starting points

### AWS

Use the AWS path if you want to:

- provision a new EKS cluster from scratch
- connect to an existing EKS cluster
- manage a delegate with Terraform
- use the included helper scripts for guided setup and cleanup

Start here:

- [`aws/README.md`](./aws/README.md)
- [`aws/QUICKSTART.md`](./aws/QUICKSTART.md)
- [`docs/aws-delegate-access-model.md`](./docs/aws-delegate-access-model.md)

### Azure

Start here:

- [`azure/README.md`](./azure/README.md)

### GCP

Start here:

- [`gcp/README.md`](./gcp/README.md)

## Architecture docs

Use these when you want to understand how the AWS sandbox access model works:

- [`docs/README.md`](./docs/README.md)
- [`docs/aws-delegate-access-model.md`](./docs/aws-delegate-access-model.md)

## Common prerequisites

Before using any cloud path, make sure you have:

- Terraform `1.5+`
- access to the target cloud account or subscription
- the relevant cloud CLI installed and authenticated
- `kubectl` installed if you plan to interact with Kubernetes directly
- `helm` installed for workflows that inspect or clean up Helm-based applications

## Recommended onboarding flow

1. Clone or fork the repository.
2. Choose the cloud directory that matches your target environment.
3. Read that cloud directory's README before changing any variables.
4. Authenticate to the target cloud provider.
5. Initialize Terraform and review the plan before applying.
6. Store sensitive values outside of Git, such as environment variables or untracked `.tfvars` files.
7. Verify cluster access and deployed resources after apply.
8. Clean up resources when you are finished to avoid unexpected cloud spend.

## Sharing and safety notes

- Do not commit credentials, tokens, or customer-specific values to the repository.
- Prefer environment variables or ignored `.tfvars` files for secrets.
- Personalize names, tags, and regions so multiple users can work in the same cloud account without collisions.
- Review every `terraform plan` carefully, especially when reusing an existing cluster.

## Need the fastest path?

If you want the smoothest first-run experience, start with the AWS quickstart:

- [`aws/QUICKSTART.md`](./aws/QUICKSTART.md)
