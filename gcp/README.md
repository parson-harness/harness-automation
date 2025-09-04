# Provision a GKE Cluster and Harness Delegate

This repo is a companion repo to the [Provision a GKE Cluster tutorial](https://developer.hashicorp.com/terraform/tutorials/kubernetes/gke), containing Terraform to provision a GKE cluster on GCP. Also included is an optional Harness Delegate YML.

This sample repo also creates a VPC and subnet for the GKE cluster. This is not
required but highly recommended to keep your GKE cluster isolated.

1. ```brew install --cask google-cloud-sdk```
1. ```gcloud init```
1. ```gcloud auth application-default login```
1. Update terraform.tfvars with the appropriate values for your cloud resources, e.g. project_id. You can find your project_id by running ```gcloud config get-value project```
1. ```terraform init```
1. ```terraform plan```
1. ```terraform apply```
1. ```gcloud container clusters get-credentials $(terraform output -raw kubernetes_cluster_name) --region $(terraform output -raw region)```

### To install k8s dashboard application
1. ```kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml```
1. ```kubectl proxy```
1. Open another terminal window and run ```kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml```
1. In the same new terminal window (while proxy continues running), run the following command to generate a token: ```kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep service-controller-token | awk '{print $1}')```
1. Login to the [Kubernetes dashboard](http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/), and use the token you just generated to authenticate.

### To install Harness delegate
1. Update harness-delegate-gke.yml references to <replace_with_delegate_token>
1. If installing in any Harness account other than the SE Sandbox account, you'll also need to update the account ID references. 
1. ```kubectl apply -f harness-delegate-gke.yml```
