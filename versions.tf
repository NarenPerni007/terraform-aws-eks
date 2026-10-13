# ------------------------------------------------------------------------------
# Terraform and provider version constraints
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state is intentionally left unconfigured so this repo works out of
  # the box. For team use, add an S3 backend with native locking, e.g.:
  #
  # backend "s3" {
  #   bucket       = "my-terraform-state"
  #   key          = "eks/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true # native S3 locking, Terraform 1.10+ (no DynamoDB table needed)
  #   encrypt      = true
  # }
}
