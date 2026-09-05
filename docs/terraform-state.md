# Terraform state

All environments default to the **local** backend so the repo works offline and
in CI without AWS credentials (`terraform init && terraform validate`).

When you are ready to `terraform apply` against a real AWS account, switch to a
shared S3 backend so state is not lost between machines.

## S3 backend (recommended for real applies)

In `terraform/envs/dev/versions.tf`, replace `backend "local" {}` with:

```hcl
backend "s3" {
  bucket         = "krish-terraform-state"
  key            = "aws-gitops/dev/terraform.tfstate"
  region         = "eu-west-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

Create the bucket + DynamoDB lock table once (any account with credentials):

```bash
aws s3api create-bucket --bucket krish-terraform-state --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

> Keep `versions.tf` local in this repo so CI validation stays credential-free.
> Apply to AWS only after credentials exist (see README "Apply to AWS").