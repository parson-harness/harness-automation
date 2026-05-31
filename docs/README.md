# Documentation

This directory contains conceptual and architecture-focused documentation for the repository.

Use these docs when you want to understand how the pieces fit together, not just how to run a single command.

## Start here

- [`aws-delegate-access-model.md`](./aws-delegate-access-model.md) - how the AWS delegate, Harness cloud connectors, IRSA, and OIDC fit together

## Where to find task-oriented docs

Operational setup and quickstart material stays close to the code:

- repo overview: [`../README.md`](../README.md)
- AWS setup guide: [`../aws/README.md`](../aws/README.md)
- AWS quickstart: [`../aws/QUICKSTART.md`](../aws/QUICKSTART.md)
- delegate helper usage: [`../aws/modules/delegate/README.md`](../aws/modules/delegate/README.md)

## Documentation philosophy

This `docs/` directory is intentionally small.

- Put conceptual, cross-cutting explanations here.
- Keep module-specific usage notes next to the module.
- Keep quickstarts in the cloud-specific directories.
- Avoid duplicating the same setup steps in multiple places.
