output "frontend_repository_url" { value = aws_ecr_repository.frontend.repository_url }
output "backend_repository_url"  { value = aws_ecr_repository.backend.repository_url }
output "registry_arn"            { value = aws_ecr_repository.frontend.arn }
