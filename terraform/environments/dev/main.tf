##############################################################
# DATA SOURCES
##############################################################

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

##############################################################
# LOCALS
##############################################################

locals {
  cluster_name = "microservices-demo-${var.environment}"
  account_id   = var.aws_account_id
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)

  services = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "loadgenerator",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice",
    "shoppingassistantservice",
  ]
}

##############################################################
# MODULE: VPC
##############################################################

module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  cluster_name         = local.cluster_name
  azs                  = local.azs
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
}

##############################################################
# MODULE: ECR
##############################################################

module "ecr" {
  source = "../../modules/ecr"

  environment = var.environment
  services    = local.services
  account_id  = local.account_id
  aws_region  = var.aws_region
}

##############################################################
# MODULE: EKS
##############################################################

module "eks" {
  source = "../../modules/eks"

  environment        = var.environment
  cluster_name       = local.cluster_name
  cluster_version    = var.cluster_version
  aws_region         = var.aws_region
  account_id         = local.account_id
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type

  vpc_cni_irsa_role_arn                 = module.iam.vpc_cni_irsa_role_arn
  aws_load_balancer_controller_role_arn = module.iam.aws_load_balancer_controller_role_arn
  external_secrets_irsa_role_arn        = module.iam.external_secrets_irsa_role_arn
  argocd_image_updater_irsa_role_arn    = module.iam.argocd_image_updater_irsa_role_arn
}

##############################################################
# MODULE: IAM
##############################################################

module "iam" {
  source = "../../modules/iam"

  environment        = var.environment
  cluster_name       = local.cluster_name
  account_id         = local.account_id
  aws_region         = var.aws_region
  github_org         = var.github_org
  github_source_repo = var.github_source_repo
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  ecr_repo_arns      = module.ecr.repository_arns
}

##############################################################
# SECRETS MANAGER
# Stores SMTP credentials for ArgoCD Notifications.
# You must manually populate the secret value after apply:
#
#   aws secretsmanager put-secret-value \
#     --secret-id microservices-demo-dev/argocd/smtp \
#     --secret-string '{"username":"anshuu.verma@gmail.com","password":"YOUR_APP_PASSWORD","from":"anshuu.verma@gmail.com"}' \
#     --region ap-south-1
#
# For Gmail: use an App Password, not your account password.
# Enable 2FA → Google Account → Security → App Passwords.
##############################################################

resource "aws_secretsmanager_secret" "argocd_smtp" {
  name                    = "${local.cluster_name}/argocd/smtp"
  description             = "SMTP credentials for ArgoCD Notifications (Gmail)"
  recovery_window_in_days = 0 # Immediate deletion allowed in dev

  tags = { Name = "${local.cluster_name}/argocd/smtp" }
}

# Placeholder value — replace manually after apply (see comment above)
resource "aws_secretsmanager_secret_version" "argocd_smtp" {
  secret_id = aws_secretsmanager_secret.argocd_smtp.id
  secret_string = jsonencode({
    username = "anshuu.verma@gmail.com"
    password = "REPLACE_WITH_GMAIL_APP_PASSWORD"
    from     = "anshuu.verma@gmail.com"
  })

  lifecycle {
    # Prevent Terraform from overwriting the value once you set the real password
    ignore_changes = [secret_string]
  }
}

##############################################################
# KUBERNETES NAMESPACES
# Created by Terraform so Helm releases have a target namespace.
# ArgoCD will manage app namespaces (demo-dev) itself.
##############################################################

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
    }
  }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
    }
  }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
    }
  }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
    }
  }
  depends_on = [module.eks]
}

##############################################################
# PLATFORM TOOL 1: AWS LOAD BALANCER CONTROLLER
#
# Must be installed FIRST — NGINX Ingress needs an NLB which
# the LBC provisions. Without it, the LoadBalancer Service
# for NGINX will stay in Pending forever.
#
# Chart: eks/aws-load-balancer-controller
# Namespace: kube-system
##############################################################

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.10.0"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.aws_load_balancer_controller_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  # Resource limits — sized for t3.small
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
    value = "128Mi"
  }

  set {
    name  = "replicaCount"
    value = "1"
  }

  depends_on = [
    module.eks,
    kubernetes_namespace.nginx_ingress,
  ]
}

##############################################################
# PLATFORM TOOL 2: NGINX INGRESS CONTROLLER
#
# Installed after LBC so the NLB is provisionable.
# Type=LoadBalancer Service → LBC creates an NLB in public
# subnets → all HTTP traffic enters through it.
#
# No TLS termination (no domain). HTTP only for this setup.
# Chart: ingress-nginx/ingress-nginx
##############################################################

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.3"
  namespace  = "ingress-nginx"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # NLB annotations — tells LBC to create an internet-facing NLB
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "external"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "ip"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }

  # Resource limits — sized for t3.small
  set {
    name  = "controller.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "controller.replicaCount"
    value = "1"
  }

  # Enable Prometheus metrics scraping
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = "true"
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

##############################################################
# PLATFORM TOOL 3: EXTERNAL SECRETS OPERATOR
#
# Syncs secrets from AWS Secrets Manager into Kubernetes
# Secret objects. ArgoCD Notifications SMTP credentials
# are pulled this way — no secrets in Git ever.
#
# Chart: external-secrets/external-secrets
##############################################################

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.10.7"
  namespace  = "external-secrets"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.external_secrets_irsa_role_arn
  }

  set {
    name  = "resources.requests.cpu"
    value = "25m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "replicaCount"
    value = "1"
  }

  depends_on = [
    kubernetes_namespace.external_secrets,
    module.eks,
  ]
}

##############################################################
# EXTERNAL SECRET: ArgoCD SMTP
#
# Creates a ClusterSecretStore (cluster-scoped) pointing at
# AWS Secrets Manager, then an ExternalSecret in argocd
# namespace that syncs the SMTP credentials into a K8s Secret.
# ArgoCD Notifications reads from that K8s Secret.
##############################################################

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "kubernetes_manifest" "argocd_smtp_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "argocd-notifications-smtp"
      namespace = "argocd"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "aws-secrets-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "argocd-notifications-smtp"
        creationPolicy = "Owner"
      }
      dataFrom = [{
        extract = {
          key = "${local.cluster_name}/argocd/smtp"
        }
      }]
    }
  }

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_manifest.cluster_secret_store,
  ]
}

##############################################################
# PLATFORM TOOL 4: ARGOCD
#
# Installed with Notifications enabled.
# Email trigger config references the K8s Secret synced by ESO.
# Image Updater installed as separate subchart.
#
# Chart: argo/argo-cd
##############################################################

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.11"
  namespace  = "argocd"

  values = [
    yamlencode({
      global = {
        # t3.small sizing — conservative resource requests
        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }

      server = {
        replicas = 1
        # Expose ArgoCD UI via NGINX Ingress (HTTP, no TLS)
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations = {
            "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
            "nginx.ingress.kubernetes.io/ssl-redirect"     = "false"
          }
          hosts = ["argocd.local"] # Access via NLB DNS or port-forward
        }
        extraArgs = ["--insecure"] # No TLS since we have no domain/cert
      }

      repoServer = {
        replicas = 1
        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "300m", memory = "256Mi" }
        }
      }

      applicationSet = {
        replicas = 1
        resources = {
          requests = { cpu = "25m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }

      dex = {
        enabled = false # Not using SSO in this setup
      }

      redis = {
        resources = {
          requests = { cpu = "25m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }

      # ── Notifications ──────────────────────────────────────
      notifications = {
        enabled  = true
        replicas = 1

        resources = {
          requests = { cpu = "25m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }

        # SMTP service config — reads password from the ESO-synced Secret
        notifiers = {
          service_email = <<-SMTP
            host: smtp.gmail.com
            port: 587
            from: $email-username
            username: $email-username
            password: $email-password
          SMTP
        }

        # Secret containing SMTP credentials (synced from Secrets Manager by ESO)
        secret = {
          items = {
            email-username = {
              secret    = "argocd-notifications-smtp"
              key       = "username"
            }
            email-password = {
              secret    = "argocd-notifications-smtp"
              key       = "password"
            }
          }
        }

        # Notification templates
        templates = {
          template_app_deployed = {
            email = {
              subject = "[ArgoCD] {{.app.metadata.name}} deployed successfully"
            }
            message = "Application {{.app.metadata.name}} has been deployed to {{.app.spec.destination.namespace}}.\nRevision: {{.app.status.sync.revision}}"
          }
          template_app_health_degraded = {
            email = {
              subject = "[ArgoCD] ALERT: {{.app.metadata.name}} health degraded"
            }
            message = "Application {{.app.metadata.name}} health status is {{.app.status.health.status}}.\nMessage: {{.app.status.health.message}}"
          }
          template_app_sync_failed = {
            email = {
              subject = "[ArgoCD] FAILED: {{.app.metadata.name}} sync failed"
            }
            message = "Application {{.app.metadata.name}} sync failed.\nError: {{.app.status.operationState.message}}"
          }
        }

        # Triggers — when to send which template
        triggers = {
          trigger_on_deployed = {
            description = "Triggered when application is synced and healthy"
            send        = ["template-app-deployed"]
            when        = "app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'"
          }
          trigger_on_health_degraded = {
            description = "Triggered when application health degrades"
            send        = ["template-app-health-degraded"]
            when        = "app.status.health.status == 'Degraded'"
          }
          trigger_on_sync_failed = {
            description = "Triggered when sync fails"
            send        = ["template-app-sync-failed"]
            when        = "app.status.operationState.phase in ['Error', 'Failed']"
          }
        }

        # Default subscriptions — all apps notify this email
        subscriptions = [{
          recipients = ["email:anshuu.verma@gmail.com"]
          triggers   = [
            "on-deployed",
            "on-health-degraded",
            "on-sync-failed",
          ]
        }]
      }

      # ── RBAC ───────────────────────────────────────────────
      configs = {
        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv" = <<-RBAC
            p, role:admin, applications, *, */*, allow
            p, role:admin, clusters, get, *, allow
            p, role:admin, repositories, *, *, allow
            p, role:admin, logs, get, *, allow
            p, role:admin, exec, create, */*, allow
            g, argocd-admins, role:admin
          RBAC
        }
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.nginx_ingress,
    helm_release.external_secrets,
    kubernetes_manifest.argocd_smtp_external_secret,
  ]
}

##############################################################
# PLATFORM TOOL 5: ARGOCD IMAGE UPDATER
#
# Watches ECR for new image tags matching "git-*" pattern.
# When a new tag is pushed, it commits updated image tag
# back to the GitOps repo, triggering ArgoCD sync.
#
# Chart: argo/argocd-image-updater
##############################################################

resource "helm_release" "argocd_image_updater" {
  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = "0.11.0"
  namespace  = "argocd"

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.iam.argocd_image_updater_irsa_role_arn
        }
      }

      config = {
        # ECR registry config — uses IRSA for auth, no static credentials
        registries = [
          {
            name        = "ECR"
            api_url     = "https://${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
            prefix      = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
            ping        = true
            credentials = "ext:/scripts/ecr-login.sh"
            credsexpire = "10h"
          }
        ]
      }

      # ECR login helper script — uses IRSA token, no access keys
      authScripts = {
        enabled = true
        scripts = {
          "ecr-login.sh" = <<-SCRIPT
            #!/bin/sh
            aws ecr get-login-password --region ${var.aws_region} | \
              echo "AWS:$(cat)"
          SCRIPT
        }
      }

      resources = {
        requests = { cpu = "25m", memory = "32Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }

      # ArgoCD server connection
      argocd = {
        grpcWeb        = true
        serverAddress  = "argocd-server.argocd.svc.cluster.local:443"
        insecure       = true
        plaintext      = true
      }
    })
  ]

  depends_on = [helm_release.argocd]
}

##############################################################
# PLATFORM TOOL 6: KUBE-PROMETHEUS-STACK
#
# Single chart installs: Prometheus, Grafana, AlertManager,
# kube-state-metrics, node-exporter, Metrics Server.
# Grafana exposed via NGINX Ingress.
#
# Chart: prometheus-community/kube-prometheus-stack
##############################################################

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "67.4.0"
  namespace  = "monitoring"

  # Timeout extended — this chart installs many CRDs and takes time
  timeout = 600

  values = [
    yamlencode({
      # ── Prometheus ─────────────────────────────────────────
      prometheus = {
        prometheusSpec = {
          retention = "7d"
          resources = {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }
          # Persistent storage for metrics (EBS via ebs-csi addon)
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes      = ["ReadWriteOnce"]
                resources        = { requests = { storage = "8Gi" } }
              }
            }
          }
          # Scrape all ServiceMonitors in all namespaces
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          replicas = 1
        }
      }

      # ── Grafana ────────────────────────────────────────────
      grafana = {
        replicas         = 1
        adminPassword    = "admin" # Change after first login
        defaultDashboardsEnabled = true

        resources = {
          requests = { cpu = "50m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }

        # Expose Grafana via NGINX Ingress
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations = {
            "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
          }
          hosts = ["grafana.local"]
          path  = "/"
        }

        persistence = {
          enabled          = true
          storageClassName = "gp2"
          size             = "2Gi"
        }

        # Pre-load dashboards for the microservices
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
      }

      # ── AlertManager ───────────────────────────────────────
      alertmanager = {
        replicas = 1
        alertmanagerSpec = {
          resources = {
            requests = { cpu = "25m", memory = "32Mi" }
            limits   = { cpu = "100m", memory = "64Mi" }
          }
        }
        config = {
          global = {
            smtp_smarthost    = "smtp.gmail.com:587"
            smtp_from         = "anshuu.verma@gmail.com"
            smtp_auth_username = "anshuu.verma@gmail.com"
            # Password injected via Kubernetes Secret by ESO in next step
            smtp_auth_password_file = "/etc/alertmanager/secrets/email-password"
          }
          route = {
            group_by        = ["alertname", "namespace"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "12h"
            receiver        = "email"
          }
          receivers = [{
            name = "email"
            email_configs = [{
              to            = "anshuu.verma@gmail.com"
              send_resolved = true
            }]
          }]
        }
      }

      # ── kube-state-metrics ─────────────────────────────────
      "kube-state-metrics" = {
        resources = {
          requests = { cpu = "25m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }

      # ── node-exporter ──────────────────────────────────────
      "prometheus-node-exporter" = {
        resources = {
          requests = { cpu = "25m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "64Mi" }
        }
      }

      # ── Operator ───────────────────────────────────────────
      prometheusOperator = {
        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    module.eks,
    helm_release.aws_load_balancer_controller,
  ]
}
