###############################################################################
# Provider
###############################################################################
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.aws_account_id]
}

terraform {
  backend "s3" {
    bucket = "481665126186-bucket-state-file-gitlab-runners-demo"
    region = "us-east-1"
    key    = "gitlabrunnerdemo.tf"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


###############################################################################
# Data Source
###############################################################################
data "aws_ami" "latest_amazon_linux_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


###############################################################################
# Locals
###############################################################################
locals {
  tags = {
    Environment = var.environment
  }
}

###############################################################################
# VPC
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "gitlab-runner-demo-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = local.tags
}

###############################################################################
# Security Group
###############################################################################
module "security-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "gitlab-runner-instance-sg"
  description = "Security group for gitlab-runner-instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]
}

###############################################################################
# EC2
###############################################################################
module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = "gitlab-runner"

  instance_type          = "t3.micro"
  vpc_security_group_ids = [module.security-group.security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  ami                    = data.aws_ami.latest_amazon_linux_ami.id

  user_data = templatefile("${path.module}/scripts/gitlab_runner_install.tpl", {
    gitlab_runner_registration_token = var.gitlab_runner_registration_token
  })

  tags = local.tags
}
