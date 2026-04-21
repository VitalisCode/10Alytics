output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

##