### Quick Start for spinning up an AKS cluster using Microsoft's TF

#### Reference
https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-terraform?tabs=bash&pivots=development-environment-azure-cli

##### Setup
1. Setup your CLI environment<br>
```az account show```<br>
```az account list --query "[?user.name=='<microsoft_account_email>'].{Name:name, ID:id, Default:isDefault}" --output Table```<br>
```az account set --subscription "<subscription_id_or_subscription_name>"```
