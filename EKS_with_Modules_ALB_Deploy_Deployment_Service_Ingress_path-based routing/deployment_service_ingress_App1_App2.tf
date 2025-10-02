############################################################
# Nginx Deployments, Services & Ingress
############################################################

# App1
resource "kubernetes_deployment" "nginx_app1" {
  metadata {
    name = "nginx-app1"
    labels = { app = "nginx-app1" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "nginx-app1" } }
    template {
      metadata { labels = { app = "nginx-app1" } }
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

resource "kubernetes_service" "nginx_app1_svc" {
  metadata {
    name = "nginx-app1-svc"
  }
  spec {
    selector = {
      app = "nginx-app1"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

# App2
resource "kubernetes_deployment" "nginx_app2" {
  metadata {
    name = "nginx-app2"
    labels = { app = "nginx-app2" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "nginx-app2" } }
    template {
      metadata { labels = { app = "nginx-app2" } }
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

resource "kubernetes_service" "nginx_app2_svc" {
  metadata {
    name = "nginx-app2-svc"
  }
  spec {
    selector = {
      app = "nginx-app2"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

# Ingress
resource "kubernetes_ingress_v1" "nginx_path_ingress" {
  metadata {
    name = "nginx-path-ingress"
    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80}]"
    }

  }

  spec {
    rule {
      http {
        path {
          path      = "/app1"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_app1_svc.metadata[0].name
              port { number = 80 }
            }
          }
        }

        path {
          path      = "/app2"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx_app2_svc.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}