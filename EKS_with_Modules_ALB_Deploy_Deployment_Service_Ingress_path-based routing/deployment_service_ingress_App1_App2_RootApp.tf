############################################################
# Terraform Version & Providers
############################################################
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.13"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}
############################################################
# AWS Provider
############################################################
provider "aws" {
  region = "ap-south-1"
}

provider "time" {}
provider "tls" {}
############################################################
# VPC
############################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.3.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway      = false
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"           = 1
    "kubernetes.io/cluster/my-cluster" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"  = 1
    "kubernetes.io/cluster/my-cluster" = "shared"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

############################################################
# EKS Cluster + Managed Node Group
############################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "my-cluster"
  kubernetes_version = "1.33"

  addons = {
    coredns                = {}
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
  }

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
############################################################
# Fetch EKS Cluster Info
############################################################
data "aws_eks_cluster" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

############################################################
# Kubernetes Provider (exec auth)
############################################################
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "ap-south-1"]
  }
}

############################################################
# Helm Provider
############################################################
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

############################################################
# Namespace for Apps
############################################################
resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

############################################################
# NGINX Apps Deployments & Services
############################################################
locals {
  apps = ["main", "app1", "app2"]
}

# Deployments
resource "kubernetes_deployment" "nginx_apps" {
  for_each = toset(local.apps)

  metadata {
    name      = "nginx-${each.key}"
    namespace = kubernetes_namespace.apps.metadata[0].name
    labels    = { app = "nginx-${each.key}" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "nginx-${each.key}" } }
    template {
      metadata { labels = { app = "nginx-${each.key}" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port { container_port = 80 }
        }
      }
    }
  }
}

# Services
resource "kubernetes_service" "nginx_apps_svc" {
  for_each = toset(local.apps)

  metadata {
    name      = "nginx-${each.key}-svc"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  spec {
    selector = { app = "nginx-${each.key}" }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

############################################################
# Ingress-NGINX Controller via Helm
############################################################
resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  timeout = 900
  wait    = true

  set = [
    { name  = "controller.service.type", value = "LoadBalancer" },
    { name  = "controller.ingressClassResource.default", value = "true" },
    { name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme", value = "internet-facing" }
  ]
}

############################################################
# Path-based Ingress
############################################################
resource "kubernetes_ingress_v1" "nginx_path_ingress" {
  metadata {
    name      = "nginx-path-ingress"
    namespace = kubernetes_namespace.apps.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_apps_svc["main"].metadata[0].name
              port { number = 80 }
            }
          }
        }
        path {
          path      = "/app1"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_apps_svc["app1"].metadata[0].name
              port { number = 80 }
            }
          }
        }
        path {
          path      = "/app2"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_apps_svc["app2"].metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}



###################################################
# ---------------- ACM Certificate ----------------
###################################################

resource "aws_acm_certificate" "app_cert" {
  domain_name       = "mrcet.kozow.com" # replace with your domain
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "app_cert_validation" {
  certificate_arn = aws_acm_certificate.app_cert.arn
}



#################################
# ACM Certificates for Both Domains
#################################

#resource "aws_acm_certificate" "multi_cert" {
#  domain_name       = "mrcet.kozow.com"
#  subject_alternative_names = [
#    "app1.mrcet.kozow.com",
#    "app2.mrcet.kozow.com"
#  ]
#  validation_method = "DNS"
#}

# DNS Validation Records (for each domain)
#resource "aws_route53_record" "cert_validation_app" {
#  name    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_name
#  type    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_type
#  zone_id = "ZXXXXXXXXXXXX" # Replace with your Route53 Hosted Zone ID
#  records = [tolist(aws_acm_certificate.multi_cert.domain_validation_options)[0].resource_record_value]
#  ttl     = 60
#}

#resource "aws_route53_record" "cert_validation_api" {
#  name    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_name
#  type    = tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_type
#  zone_id = "ZXXXXXXXXXXXX"
#  records = [tolist(aws_acm_certificate.multi_cert.domain_validation_options)[1].resource_record_value]
#  ttl     = 60
#}

#resource "aws_acm_certificate_validation" "multi_cert_validation" {
#  certificate_arn         = aws_acm_certificate.multi_cert.arn
#  validation_record_fqdns = [
#    aws_route53_record.cert_validation_app.fqdn,
#    aws_route53_record.cert_validation_api.fqdn
#  ]
}


# ---------------- Listeners ----------------
#resource "aws_lb_listener" "https" {
#  load_balancer_arn = aws_lb.app_lb.arn
#  port              = "443"
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = aws_acm_certificate_validation.app_cert_validation.certificate_arn

#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_tg_root.arn
#  }
#}

# Path-based routing rules
#resource "aws_lb_listener_rule" "root_rule" {
#  listener_arn = aws_lb_listener.https.arn
#  priority     = 10

#  action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_tg_root.arn
#  }

#  condition {
#    path_pattern {
#      values = ["/"]
#    }
#  }
#}

#resource "aws_lb_listener_rule" "payment_rule" {
#  listener_arn = aws_lb_listener.https.arn
#  priority     = 20

#  action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_tg_payment.arn
#  }

#  condition {
#    path_pattern {
#      values = ["/payment*"]
#    }
#  }
#}

# HTTP → HTTPS Redirect
#resource "aws_lb_listener" "http_redirect" {
#  load_balancer_arn = aws_lb.app_lb.arn
#  port              = "80"
#  protocol          = "HTTP"

#  default_action {
#    type = "redirect"
#    redirect {
#      port        = "443"
#      protocol    = "HTTPS"
#      status_code = "HTTP_301"
#    }
#  }
#}
