# Siamo POC #8 — Infrastructure as Code, Terraform track.
#
# Declares the microservices POC shape (2 services) as Kubernetes objects:
#   - 1 namespace
#   - 2 deployments (frontend :8081, backend :8082) running image siamo/orders:demo
#   - 2 ClusterIP services
#   - 2 HorizontalPodAutoscalers (CPU-based, 2–5 replicas)
#
# This is a DECLARATIVE description of infrastructure: "make the cluster look
# like this." `terraform plan` computes the diff; `terraform apply` converges
# the cluster toward it; the state file records what Terraform last created.
#
# NOTE: `terraform init` downloads the kubernetes provider (network needed).
# `terraform validate` checks syntax + provider schema — it needs NO cluster.

terraform {
  required_version = ">= 1.5"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used to reach the target cluster."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubeconfig context to use (empty = current context)."
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Namespace for all demo objects."
  type        = string
  default     = "siamo-demo"
}

variable "image" {
  description = "Container image for both demo services (placeholder demo tag)."
  type        = string
  default     = "siamo/orders:demo"
}

locals {
  # The microservices shape: two services, their ports, and base replicas.
  services = {
    frontend = { port = 8081, replicas = 2 }
    backend  = { port = 8082, replicas = 2 }
  }
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "svc" {
  for_each = local.services

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels    = { app = each.key }
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = { app = each.key }
    }

    template {
      metadata {
        labels = { app = each.key }
      }

      spec {
        container {
          name  = each.key
          image = var.image

          port {
            container_port = each.value.port
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = each.value.port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = each.value.port
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "svc" {
  for_each = local.services

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels    = { app = each.key }
  }

  spec {
    selector = { app = each.key }
    port {
      name        = "http"
      port        = 80
      target_port = each.value.port
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "svc" {
  for_each = local.services

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  spec {
    min_replicas = 2
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.svc[each.key].metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

output "namespace" {
  value = kubernetes_namespace.demo.metadata[0].name
}

output "services" {
  description = "Deployed service names."
  value       = [for s in kubernetes_service.svc : s.metadata[0].name]
}
