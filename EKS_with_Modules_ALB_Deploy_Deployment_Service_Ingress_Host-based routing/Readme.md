Here’s a full Terraform snippet for two Nginx apps with host-based routing using AWS ALB Ingress and fixed port blocks. This assumes your EKS cluster, VPC, and AWS Load Balancer Controller are already set up.

############################################################
# Nginx Deployments and Services
############################################################

# App1 Deployment
resource "kubernetes_deployment" "nginx_app1" {
  metadata {
    name   = "nginx-app1"
    labels = { app = "nginx-app1" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "nginx-app1" }
    }
    template {
      metadata { labels = { app = "nginx-app1" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# App1 Service
resource "kubernetes_service" "nginx_app1_svc" {
  metadata {
    name = "nginx-app1-svc"
  }
  spec {
    selector = { app = "nginx-app1" }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

# App2 Deployment
resource "kubernetes_deployment" "nginx_app2" {
  metadata {
    name   = "nginx-app2"
    labels = { app = "nginx-app2" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "nginx-app2" }
    }
    template {
      metadata { labels = { app = "nginx-app2" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# App2 Service
resource "kubernetes_service" "nginx_app2_svc" {
  metadata {
    name = "nginx-app2-svc"
  }
  spec {
    selector = { app = "nginx-app2" }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

############################################################
# Ingress: Host-Based Routing
############################################################

resource "kubernetes_ingress_v1" "nginx_host_ingress" {
  metadata {
    name = "nginx-host-ingress"
    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80}]"
    }
  }

  spec {
    rule {
      host = "app1.example.com"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_app1_svc.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = "app2.example.com"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_app2_svc.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

✅ Key Notes:

Host-based routing:

app1.example.com → App1

app2.example.com → App2

Port blocks fixed:

No single-line multiple attribute blocks.

ALB annotations:

internet-facing scheme for public access.

target-type: ip for pod IP targets.

Update your DNS records to point app1.example.com and app2.example.com to the ALB once it’s created.


