# Harness Delegate Scripts

## Install (Helm)

- **Uniqueness:** `DELEGATE_NAME` must be unique per namespace. The Helm release name is automatically derived from `DELEGATE_NAME` (lowercased/trimmed).
- The script prompts for missing inputs and reads from root `terraform output` where possible.

### Minimal

```bash
cd aws

export HARNESS_ACCOUNT_ID="<your-harness-account>"
export DELEGATE_TOKEN="<a-secure-token>"
export DELEGATE_NAME="demo-delegate"

./delegate/install_delegate.sh
```

### Dynamic image resolution
If you **don’t** set `DELEGATE_IMAGE`, the script will:
1) Fetch the **latest** `harness/delegate` tag from Docker Hub (no auth required).  
2) If Docker Hub is unavailable, and you set `HARNESS_API_KEY`, it will query the Harness API for the **latest supported version**.

You can override with:
```bash
export DELEGATE_IMAGE="us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:<tag>"
# or change the prefix (defaults to GAR path above)
export DELEGATE_IMAGE_PREFIX="us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate"
```

The script writes a **temporary `values.yaml`** with proper quoting (fixes YAML parse errors).

### Other options

- `NS` (namespace, default: `harness-delegate-ng`)
- `SA` (ServiceAccount, default: `harness-delegate`)
- `REGION`, `CLUSTER_NAME` (if kubeconfig isn’t already pointed at the cluster)
- `MANAGER_ENDPOINT`, `DELEGATE_REPLICAS`
- `IRSA_ROLE_ARN` (auto-read from TF output if present)

## Uninstall

Use the root `destroy.sh` to target delegates precisely:

```bash
# remove by delegate name (release auto-resolved)
./destroy.sh --delegate --delegate-name demo-delegate --yes

# or list first
./destroy.sh --delegate --list
```
