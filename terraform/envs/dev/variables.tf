variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name, used for names and tags"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "gitops-demo"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "db_instance_class" {
  description = "RDS instance class (dev = smallest; bump for prod)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Name of the demo Postgres database"
  type        = string
  default     = "demoapp"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "demoapp"
}

variable "db_password" {
  description = "RDS master password. Override from TF_VAR_db_password or tfvars in real usage."
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "ecr_services" {
  description = "Demo services backed by an ECR repository each"
  type        = list(string)
  default     = ["api", "worker", "web"]
}

variable "argocd_chart_version" {
  type    = string
  default = "7.7.12"
}

variable "external_secrets_chart_version" {
  type    = string
  default = "0.10.6"
}

variable "kube_prometheus_stack_chart_version" {
  type    = string
  default = "62.7.0"
}

variable "ingress_nginx_chart_version" {
  type    = string
  default = "4.11.3"
}

variable "acme_email" {
  description = "Email for Let's Encrypt notifications (optional until a real domain is attached)"
  type        = string
  default     = ""
}