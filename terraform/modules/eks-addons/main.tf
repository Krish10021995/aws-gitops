# ---------------------------------------------------------------------------
# ArgoCD + Argo CD Image Updater
# ---------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600

  set {
    name  = "configs.params['server.insecure']"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.argocd_role_arn
  }
}

resource "helm_release" "argocd_image_updater" {
  name             = "argocd-image-updater"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-image-updater"
  version          = "0.9.0"
  namespace        = "argocd"
  create_namespace = false
  timeout          = 600

  set {
    name  = "config.argocd.grpcAddress"
    value = "argocd-server.argocd.svc.cluster.local"
  }

  set {
    name  = "config.argocd.insecure"
    value = "true"
  }
}

# ---------------------------------------------------------------------------
# external-secrets -> AWS Secrets Manager
# ---------------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 600

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_secrets_role_arn
  }
}

# ---------------------------------------------------------------------------
# Observability: kube-prometheus-stack (Prometheus + Grafana)
# ---------------------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.kube_prometheus_stack_chart_version
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900

  set {
    name  = "grafana.adminPassword"
    value = "admin"
  }
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller (provisions ALBs for TLS ingresses)
# ---------------------------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.10.1"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.alb_controller_role_arn
  }
}

# ---------------------------------------------------------------------------
# ingress-nginx (kept as a documented alternative to the ALB ingress)
# ---------------------------------------------------------------------------
resource "helm_release" "ingress_nginx" {
  count            = var.acme_email != "" ? 1 : 0
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = "ingress-nginx"
  create_namespace = true
  timeout          = 600
}