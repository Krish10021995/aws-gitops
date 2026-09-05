locals {
  project = "aws-gitops"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = local.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source             = "../../modules/vpc"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "ecr" {
  source      = "../../modules/ecr"
  environment = var.environment
  services    = var.ecr_services
}

module "rds" {
  source             = "../../modules/rds"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  app_security_group = module.eks.cluster_security_group_id
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  db_instance_class  = var.db_instance_class
}

module "eks" {
  source              = "../../modules/eks"
  environment         = var.environment
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

module "eks_addons" {
  source                              = "../../modules/eks-addons"
  environment                         = var.environment
  cluster_name                        = module.eks.cluster_name
  argocd_role_arn                     = module.eks.argocd_role_arn
  alb_controller_role_arn             = module.eks.alb_controller_role_arn
  external_secrets_role_arn           = module.eks.external_secrets_role_arn
  argocd_chart_version                = var.argocd_chart_version
  external_secrets_chart_version      = var.external_secrets_chart_version
  kube_prometheus_stack_chart_version = var.kube_prometheus_stack_chart_version
  ingress_nginx_chart_version         = var.ingress_nginx_chart_version
  acme_email                          = var.acme_email
}