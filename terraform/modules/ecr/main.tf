# ============================================================
# ECR Repositories — one per microservice
# ============================================================

resource "aws_ecr_repository" "services" {
  for_each = toset(var.services)

  name                 = "microservices-demo/${each.key}"
  image_tag_mutability = "MUTABLE"

  # Encrypt images at rest with AWS-managed key
  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Service     = each.key
    Environment = var.environment
  }
}

# ---- Lifecycle policy: keep last 10 images per repo ----
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = toset(var.services)
  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
