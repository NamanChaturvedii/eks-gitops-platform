terraform {
  required_version = ">= 1.10"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "eks-gitops-tfstate-287629436195"
    key          = "eks/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # S3 native locking (no DynamoDB)
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "eks-gitops-platform"
      ManagedBy = "terraform"
    }
  }
}
