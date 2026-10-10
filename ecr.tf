# deploy/terraform/aws/ecr.tf

locals {
  services = ["web", "rest", "worker", "billing", "agent", "detector", "migrate-clickhouse", "migrate-postgres"]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.services)

  name                 = "${var.name}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Simple for now

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

# Auto-delete old images beyond the configured retention count.
#
# A buildx push stores several manifests under one tag: an image index plus the
# platform image and an attestation it references. A count over tagStatus "any"
# counts every one of those, so it keeps far fewer builds than its number says
# and can expire the build that is running. Count tagged images instead (one per
# build), and expire untagged manifests separately: ECR does not expire a
# manifest that a tagged index still references, so this only removes the
# children of builds rule 1 expired and images whose tag moved elsewhere.
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last ${var.ecr_image_retention_count} tagged builds"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.ecr_image_retention_count
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged manifests no build references"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
    ]
  })
}
