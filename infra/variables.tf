variable "region" {
  default = "us-east-1"
}

variable "db_username" {
  description = "Database master username"
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  sensitive   = true
}

variable "cluster_name" {
  default = "devops-eks"
}