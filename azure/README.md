### Quick Start for spinning up an AKS cluster
This will spin up a 2-node AKS cluster in the centralus region in the Harness-SE subscription. The name of the cluster and resource group is a combination of the variables.tf settings and a randomly generated animal name using [random_pet](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet).

#### Reference
* [Azure tutorial](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-terraform?tabs=bash&pivots=development-environment-azure-cli)
* [Azure tutorial GH repo with TF code](https://github.com/Azure/terraform/tree/master/quickstart/201-k8s-cluster-with-tf-and-aks)

#### Setup
Make sure you have Terraform, the Azure CLI, and kubectl installed locally. 
1. Setup your CLI environment<br>
```az login```<br>
```az account show```<br>
```az account list --query "[?user.name=='<microsoft_account_email>'].{Name:name, ID:id, Default:isDefault}" --output Table```<br>
```az account set --subscription "<subscription_id_or_subscription_name>"```
1. Initialize terraform<br>
   ```terraform init -upgrade```
3. Run terraform plan<br>
```terraform plan -out main.tfplan```
4. Apply the terraform plan<br>
```terraform apply main.tfplan```
5. Check your results<br>
```resource_group_name=$(terraform output -raw resource_group_name)```<br>
```az aks list --resource-group $resource_group_name --query "[].{\"K8s cluster name\":name}" --output table```<br>
6. Store the k8s config from the terraform state file to be used by kubectl in future<br>
```echo "$(terraform output kube_config)" > ./azurek8s```
7. Set an env to be picked up by kubectl<br>
```export KUBECONFIG=./azurek8s```
