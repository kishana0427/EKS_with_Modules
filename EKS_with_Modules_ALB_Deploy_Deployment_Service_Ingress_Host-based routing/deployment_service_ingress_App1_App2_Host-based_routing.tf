############################################################
# Namespace
############################################################
resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

############################################################
# App1 Deployment + Service
############################################################
resource "kubernetes_deployment_v1" "app1" {
  metadata {
    name      = "app1"
    namespace = kubernetes_namespace.apps.metadata[0].name
    labels = {
      app = "app1"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "app1"
      }
    }
    template {
      metadata {
        labels = {
          app = "app1"
        }
      }
      spec {
        container {
          name  = "app1"
          image = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app1" {
  metadata {
    name      = "app1"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }
  spec {
    selector = {
      app = "app1"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

############################################################
# App2 Deployment + Service
############################################################
resource "kubernetes_deployment_v1" "app2" {
  metadata {
    name      = "app2"
    namespace = kubernetes_namespace.apps.metadata[0].name
    labels = {
      app = "app2"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "app2"
      }
    }
    template {
      metadata {
        labels = {
          app = "app2"
        }
      }
      spec {
        container {
          name  = "app2"
          image = "httpd"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app2" {
  metadata {
    name      = "app2"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }
  spec {
    selector = {
      app = "app2"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

############################################################
# Ingress with Host-Based Routing (AWS ALB)
############################################################
resource "kubernetes_ingress_v1" "apps_ingress" {
  metadata {
    name      = "apps-ingress"
    namespace = kubernetes_namespace.apps.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"             = "alb"
      "alb.ingress.kubernetes.io/scheme"        = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"   = "ip"
    }
  }
  spec {
    rule {
      host = "app1.mrcet.kozow.com"
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.app1.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = "app2.mrcet.kozow.com"
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.app2.metadata[0].name
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
