locals {
  repos = [for s in var.services : "${s}-${var.environment}"]
}

resource "aws_ecr_repository" "this" {
  for_each             = toset(local.repos)
  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = each.key }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = <<-EOT
  {
    "rules": [
      {
        "rulePriority": 1,
        "description": "Keep last 20 images",
        "selection": {
          "tagStatus": "any",
          "countType": "imageCountMoreThan",
          "countNumber": 20
        },
        "action": { "type": "expire" }
      }
    ]
  }
  EOT
}

output "repository_urls" {
  value = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_names" {
  value = local.repos
}