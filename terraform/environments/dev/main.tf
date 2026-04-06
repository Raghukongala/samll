terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "myapp-terraform-state-dev"
    key            = "microservices/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  project = "myapp"
  env     = "dev"

  common_tags = {
    Project     = local.project
    Environment = local.env
    ManagedBy   = "Terraform"
  }
}

# ── VPC ──────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project            = local.project
  env                = local.env
  cidr_block         = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]
  tags               = local.common_tags
}

# ── ECR ──────────────────────────────────────

module "ecr" {
  source = "../../modules/ecr"

  project = local.project
  env     = local.env
  tags    = local.common_tags
}

# ── ECS ──────────────────────────────────────

module "ecs" {
  source = "../../modules/ecs"

  project            = local.project
  env                = local.env
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets

  ecr_base = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.project}/${local.env}"

  image_tag = var.image_tag
  tags      = local.common_tags
}

data "aws_caller_identity" "current" {}
