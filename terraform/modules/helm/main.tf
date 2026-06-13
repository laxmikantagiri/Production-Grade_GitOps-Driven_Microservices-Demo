# ============================================================
# HELM MODULE — Cluster Tooling
#
# Deploys (in dependency order):
#   1. aws-load-balancer-controller  — creates the single AWS ALB
#   2. ingress-nginx                 — internal routing layer
#   3. metrics-server                — required for HPA
#   4. cluster-autoscaler            — EC2 node scaling
#   5. argocd                        — GitOps CD + email notifications
#   6. kube-prometheus-stack         — Prometheus + Grafana + Alertmanager
#
# Traffic flow:
#   Internet → AWS ALB → NGINX Ingress Controller → Services
# ============================================================

# ============================================================
# NAMESPACE CREATION
# ============================================================

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "boutique" {
  metadata {
    name = "boutique-app"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ============================================================
# 1. AWS LOAD BALANCER CONTROLLER
# ============================================================

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.11.0"
  namespace  = "kube-system"

  wait    = true
  timeout = 300

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = ""
  }

  set {
    name  = "replicaCount"
    value = "2"
  }

  set {
    name  = "podDisruptionBudget.maxUnavailable"
    value = "1"
  }
}

# ============================================================
# 2. NGINX INGRESS CONTROLLER
# ============================================================

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.1"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      controller = {
        replicaCount = 2

        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
          }
        }

        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }

        podDisruptionBudget = {
          enabled      = true
          minAvailable = 1
        }

        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }

        config = {
          "use-forwarded-headers"      = "true"
          "compute-full-forwarded-for" = "true"
          "proxy-buffer-size"          = "16k"
          "use-gzip"                   = "true"
          "keep-alive"                 = "75"
          "keep-alive-requests"        = "1000"
        }
      }
    })
  ]

  depends_on = [helm_release.aws_load_balancer_controller]
}

# ============================================================
# 3. METRICS SERVER
# ============================================================

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"
  namespace  = "kube-system"

  wait    = true
  timeout = 180

  set {
    name  = "args[0]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  set {
    name  = "args[1]"
    value = "--kubelet-use-node-status-port"
  }

  set {
    name  = "args[2]"
    value = "--metric-resolution=15s"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }
}

# ============================================================
# 4. CLUSTER AUTOSCALER
# ============================================================

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.46.6"
  namespace  = "kube-system"

  wait    = true
  timeout = 300

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = ""
  }

  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "5m"
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "5m"
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "300m"
  }

  set {
    name  = "resources.limits.memory"
    value = "512Mi"
  }

  depends_on = [helm_release.metrics_server]
}

# ============================================================
# 5. ARGOCD
# ============================================================

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.26"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      global = {
        domain = ""
      }

      configs = {
        params = {
          "server.insecure" = true
        }

        cm = {
          "kustomize.buildOptions" = "--enable-helm"
          "resource.customizations" = ""
        }

        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv"     = "p, role:admin, applications, *, */*, allow\np, role:admin, clusters, *, *, allow\np, role:admin, repositories, *, *, allow\ng, admin, role:admin\n"
        }
      }

      server = {
        replicas = 2
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations      = { "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP" }
          hostname         = ""
          tls              = false
        }
      }

      repoServer = {
        replicas = 2
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "1000m", memory = "1Gi" }
        }
      }

      applicationSet = {
        replicas = 2
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "300m", memory = "512Mi" }
        }
      }

      controller = {
        resources = {
          requests = { cpu = "250m", memory = "256Mi" }
          limits   = { cpu = "1000m", memory = "1Gi" }
        }
      }

      redis = {
        resources = {
          requests = { cpu = "100m", memory = "64Mi" }
          limits   = { cpu = "300m", memory = "128Mi" }
        }
      }

      notifications = {
        enabled = true
        secret  = { create = false }
        cm      = { create = true }
        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }
    })
  ]

  depends_on = [helm_release.ingress_nginx]
}

resource "kubernetes_secret" "argocd_notifications" {
  metadata {
    name      = "argocd-notifications-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "email-username" = var.argocd_notification_email
    "email-password" = "REPLACE_WITH_GMAIL_APP_PASSWORD"
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_config_map" "argocd_notifications_cm" {
  metadata {
    name      = "argocd-notifications-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "service.email.gmail" = yamlencode({
      host     = "smtp.gmail.com"
      port     = 587
      from     = var.argocd_notification_email
      username = "$email-username"
      password = "$email-password"
    })

    "template.app-sync-failed" = yamlencode({
      email = {
        subject = "ArgoCD | Sync FAILED: {{.app.metadata.name}}"
        body    = "Application: {{.app.metadata.name}}\nSync Status: FAILED\nMessage: {{.app.status.operationState.message}}\nTimestamp: {{.app.status.operationState.finishedAt}}\n\nView in ArgoCD: {{.context.argocdUrl}}/applications/{{.app.metadata.name}}\n"
      }
    })

    "template.app-health-degraded" = yamlencode({
      email = {
        subject = "ArgoCD | Health DEGRADED: {{.app.metadata.name}}"
        body    = "Application: {{.app.metadata.name}}\nHealth Status: DEGRADED\nTimestamp: {{.app.status.reconciledAt}}\n\nView in ArgoCD: {{.context.argocdUrl}}/applications/{{.app.metadata.name}}\n"
      }
    })

    "template.app-sync-succeeded" = yamlencode({
      email = {
        subject = "ArgoCD | Sync Succeeded: {{.app.metadata.name}}"
        body    = "Application: {{.app.metadata.name}}\nSync Status: Succeeded\nRevision: {{.app.status.sync.revision}}\nTimestamp: {{.app.status.operationState.finishedAt}}\n"
      }
    })

    "trigger.on-sync-failed" = yamlencode({
      when    = "app.status.operationState.phase in ['Error', 'Failed']"
      send    = ["app-sync-failed"]
      oncePer = "app.status.operationState.syncResult.revision"
    })

    "trigger.on-health-degraded" = yamlencode({
      when    = "app.status.health.status == 'Degraded'"
      send    = ["app-health-degraded"]
      oncePer = "app.status.reconciledAt"
    })

    "trigger.on-sync-succeeded" = yamlencode({
      when    = "app.status.operationState.phase in ['Succeeded']"
      send    = ["app-sync-succeeded"]
      oncePer = "app.status.operationState.syncResult.revision"
    })

    "defaultTriggers" = yamlencode(["on-sync-failed", "on-health-degraded", "on-sync-succeeded"])

    "subscriptions" = yamlencode([{
      recipients = ["email:${var.argocd_notification_email}"]
      triggers   = ["on-sync-failed", "on-health-degraded", "on-sync-succeeded"]
    }])
  }

  depends_on = [helm_release.argocd]
}

# ============================================================
# 6. KUBE-PROMETHEUS-STACK
# ============================================================

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "70.4.2"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  wait      = true
  timeout   = 600
  skip_crds = false

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "15d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources        = { requests = { storage = "20Gi" } }
              }
            }
          }
          resources = {
            requests = { cpu = "200m", memory = "512Mi" }
            limits   = { cpu = "1000m", memory = "2Gi" }
          }
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }

      grafana = {
        enabled       = true
        adminPassword = "admin"
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations      = { "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP" }
          hosts            = [""]
          tls              = []
        }
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [{
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options         = { path = "/var/lib/grafana/dashboards/default" }
            }]
          }
        }
        dashboards = {
          default = {
            kubernetes-cluster = { gnetId = 7249, revision = 1, datasource = "Prometheus" }
            node-exporter      = { gnetId = 1860, revision = 37, datasource = "Prometheus" }
            nginx-ingress      = { gnetId = 9614, revision = 1, datasource = "Prometheus" }
          }
        }
        persistence = {
          enabled          = true
          storageClassName = "gp3"
          size             = "5Gi"
        }
      }

      alertmanager = {
        alertmanagerSpec = {
          resources = {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "200m", memory = "256Mi" }
          }
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources        = { requests = { storage = "2Gi" } }
              }
            }
          }
        }
        config = {
          global = {
            smtp_smarthost     = "smtp.gmail.com:587"
            smtp_from          = var.argocd_notification_email
            smtp_auth_username = var.argocd_notification_email
            smtp_auth_password = "REPLACE_WITH_GMAIL_APP_PASSWORD"
            smtp_require_tls   = true
          }
          route = {
            group_by        = ["alertname", "namespace"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "4h"
            receiver        = "email"
          }
          receivers = [{
            name = "email"
            email_configs = [{
              to            = var.argocd_notification_email
              send_resolved = true
            }]
          }]
        }
      }

      nodeExporter     = { enabled = true }
      kubeStateMetrics = { enabled = true }

      defaultRules = {
        create = true
        rules = {
          alertmanager              = true
          etcd                      = false
          configReloaders           = true
          general                   = true
          kubeApiserverAvailability = true
          kubeApiserverBurnrate     = true
          kubeApiserverHistogram    = true
          kubeApiserverSlos         = true
          kubeControllerManager     = false
          kubelet                   = true
          kubeProxy                 = false
          kubeSchedulerAlerting     = false
          kubeSchedulerRecording    = false
          kubeStateMetrics          = true
          network                   = true
          node                      = true
          nodeExporterAlerting      = true
          nodeExporterRecording     = true
          prometheus                = true
          prometheusOperator        = true
        }
      }
    })
  ]

  depends_on = [helm_release.ingress_nginx, helm_release.metrics_server]
}
