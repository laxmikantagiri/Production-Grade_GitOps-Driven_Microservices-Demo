# Project Overview

This repository contains a production-grade, GitOps-driven microservices demonstration of the "Online Boutique" application. It showcases a modern, highly scalable architecture composed of 11 microservices communicating via gRPC. The project is designed to demonstrate advanced DevOps and Platform Engineering practices, including Infrastructure as Code (Terraform), GitOps (ArgoCD), CI/CD (GitHub Actions), Observability (Prometheus/Grafana), and Cloud-native networking (Gateway API).

## Architecture

The application is built using a microservices architecture where each service handles a specific business function. Most services are stateless, with the exception of the `cartservice`, which uses Redis for persistence.

### Microservices Breakdown

| Service | Language | Description |
| :--- | :--- | :--- |
| **frontend** | Go | Serves the website via HTTP. |
| **cartservice** | C# | Manages user shopping carts using Redis. |
| **productcatalogservice** | Go | Provides product information from a JSON file. |
| **currencyservice** | Node.js | Handles currency conversion using real exchange rates. |
| **paymentservice** | Node.js | Mocks credit card processing. |
| **shippingservice** | Go | Estimates and simulates shipping. |
| **emailservice** | Python | Mocks order confirmation emails. |
| **checkoutservice** | Go | Orchestrates the checkout process (payment, shipping, email). |
| **recommendationservice** | Python | Dynamically generates product recommendations. |
| **adservice** | Java | Provides context-aware text advertisements. |
| **loadgenerator** | Python | Simulates realistic user traffic using Locust. |

## Infrastructure & Deployment

### Infrastructure as Code (Terraform)
The underlying AWS infrastructure (EKS cluster, VPC, etc.) is provisioned using Terraform located in the `terraform/` directory.

**Key Commands:**
- `cd terraform`
- `terraform init`
- `terraform plan`
- `terraform apply`

### GitOps (ArgoCD)
Deployment is managed declaratively via ArgoCD. Application manifests are stored in `argocd/` and use Kustomize to combine Helm charts with environment-specific Kubernetes manifests.

### CI/CD (GitHub Actions)
Continuous Integration is implemented via GitHub Actions:
- **Microservice CI:** Automatically builds and pushes Docker images to GHCR upon changes to a service in `src/`.
- **Image Updating:** `argocd-image-updater` is used to automatically update the deployed images in ArgoCD when new versions are pushed to the registry.

## Observability

The observability stack is managed independently of ArgoCD to ensure stability.
- **Monitoring:** Prometheus and Grafana (via `kube-prometheus-stack`) are used for metric collection and visualization.
- **Alerting:** Alertmanager is configured to send critical alerts to Slack via webhooks.

## Development Conventions

- **Communication:** Services primarily communicate over **gRPC**.
- **Containerization:** Each service includes a `Dockerfile` for containerization.
- **Protobufs:** API definitions are maintained in the `protos/` directory.
- **Scripting:** Many services include `genproto.sh` to generate gRPC code from protobuf definitions.
- **Testing:** Service-specific tests are located within their respective `src/` directories (e.g., `product_catalog_test.go` in `productcatalogservice`).

## Key Directories

- `argocd/`: ArgoCD Application manifests.
- `docs/`: Detailed documentation, architecture diagrams, and tutorials.
- `helm/`: Helm charts for deploying the boutique application.
- `observability/`: Configuration for Prometheus and Grafana.
- `protos/`: Protocol Buffer definitions for gRPC communication.
- `scripts/`: Utility scripts for cluster verification and smoke testing.
- `src/`: Source code for all microservices.
- `terraform/`: Infrastructure as Code definitions.
