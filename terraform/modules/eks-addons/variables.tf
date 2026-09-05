variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "argocd_role_arn" {
  description = "IRSA role ARN for ArgoCD application controller"
  type        = string
}

variable "alb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  type        = string
}

variable "external_secrets_role_arn" {
  description = "IRSA role ARN for external-secrets"
  type        = string
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
  type    = string
  default = ""
}