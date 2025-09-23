# Harness Delegate Scripts

## Install (Helm)

- `DELEGATE_NAME` must be unique per namespace. Helm release name is derived automatically.
- Prompts for missing inputs.

```bash
cd aws/delegate

DELEGATE_NAME="demo-delegate" HARNESS_ACCOUNT_ID="<your-harness-account>" DELEGATE_TOKEN="<a-secure-token>" ./install_delegate.sh
```

With IRSA:

```bash
IRSA_ROLE_ARN="$(cd .. && terraform output -raw delegate_role_arn)" DELEGATE_NAME="demo-delegate" HARNESS_ACCOUNT_ID="<your-harness-account>" DELEGATE_TOKEN="<a-secure-token>" ./install_delegate.sh
```

## Uninstall

```bash
../destroy.sh --delegate --delegate-name demo-delegate --yes
# or
../destroy.sh --delegate --list
```
