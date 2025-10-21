# Backend Bootstrap (S3 + DynamoDB)

One-time creation of an S3 bucket (versioned, encrypted, TLS-only) for Terraform remote state and a DynamoDB table for state locks.

## Usage

```bash
cd aws/backend-bootstrap
terraform init
terraform apply -auto-approve   -var='bucket_name=<globally-unique-s3-bucket>'   -var='region=us-east-1'   -var='dynamodb_table=terraform-locks'
```

## Outputs

- `bucket` – S3 bucket name
- `table` – DynamoDB table name

Then run `./tf-init.sh` from `aws/` to initialize remote state.
