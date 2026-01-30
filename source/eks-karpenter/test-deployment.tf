# ============================================================
# TEST DEPLOYMENT - Verify Karpenter Autoscaling
# ============================================================
# This deployment creates pods that require Karpenter to provision
# new nodes. Use this to test and observe Karpenter behavior.
#
# To scale and test:
#   kubectl scale deployment nginx-test --replicas=5
#   kubectl scale deployment nginx-test --replicas=1
#
# Watch Karpenter logs:
#   kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f

# ============================================================
# TEST NAMESPACE
# ============================================================
resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
    labels = {
      name    = "test"
      purpose = "karpenter-experiment"
    }
  }

  depends_on = [
    module.eks
  ]
}

# ============================================================
# NGINX TEST DEPLOYMENT
# ============================================================
# Simple nginx deployment with resource requests to trigger
# Karpenter node provisioning
resource "kubernetes_deployment" "nginx_test" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace.test.metadata[0].name
    labels = {
      app     = "nginx-test"
      purpose = "karpenter-autoscaling-test"
    }
  }

  spec {
    # Start with 1 replicas to trigger Karpenter
    replicas = 1

    selector {
      match_labels = {
        app = "nginx-test"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-test"
        }
      }

      spec {
        # Anti-affinity to spread pods across nodes
        # This forces Karpenter to create multiple nodes
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["nginx-test"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          name  = "nginx"
          image = "nginx:latest"

          # Resource requests trigger Karpenter provisioning
          # Adjust these to experiment with different node sizes
          resources {
            requests = {
              cpu    = "1"      # 1 CPU core
              memory = "1Gi"    # 1 GB memory
            }
            limits = {
              cpu    = "2"
              memory = "2Gi"
            }
          }

          port {
            container_port = 80
            name           = "http"
          }

          # Liveness probe
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          # Readiness probe
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    kubectl_manifest.karpenter_node_pool
  ]
}

# ============================================================
# SERVICE - Expose nginx for testing (optional)
# ============================================================
# resource "kubernetes_service" "nginx_test" {
#   metadata {
#     name      = "nginx-test"
#     namespace = kubernetes_namespace.test.metadata[0].name
#     labels = {
#       app = "nginx-test"
#     }
#   }

#   spec {
#     selector = {
#       app = "nginx-test"
#     }

#     port {
#       port        = 80
#       target_port = 80
#       protocol    = "TCP"
#       name        = "http"
#     }

#     type = "ClusterIP"
#   }

#   depends_on = [
#     kubernetes_deployment.nginx_test
#   ]
# }
