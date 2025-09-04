# Provision an EKS Cluster

This repo is a companion repo to the [Provision an EKS Cluster tutorial](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks), containing
Terraform to provision an EKS cluster on AWS and IAM roles needed to create a Harness Delegate and AWS Connector.

1. ```brew install awscli```
1. Authenticate (via Okta) to AWS and gain access keys needed to authenticate with the CLI.
1. Update variables.tf with appropriate metadata for your cloud resources, e.g. region, tag, etc.
1. ```terraform init```
1. ```terraform plan```
1. ```terraform apply```
1. Update your kubectl context with values from the outputs.tf. ```aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)```
1. ```kubectl cluster-info```

### After apply, annotate the ServiceAccount
1. ```kubectl -n $(terraform output -raw delegate_namespace 2>/dev/null || echo harness-delegate) \
  annotate serviceaccount $(terraform output -raw delegate_service_account 2>/dev/null || echo harness-delegate) \
  eks.amazonaws.com/role-arn=$(terraform output -raw delegate_role_arn) --overwrite```
1. ```terraform apply \
  -var 'assume_role_arns=["arn:aws:iam::111122223333:role/harness-ecs-deployer","arn:aws:iam::444455556666:role/harness-iac-admin"]'```

