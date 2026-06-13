variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "git_repo_url" {
  description = "Git repo URL ArgoCD watches for app manifests"
  type        = string
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  sensitive   = true
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "pgadmin_email" {
  description = "pgAdmin login email"
  type        = string
  sensitive   = true
}

variable "pgadmin_password" {
  description = "pgAdmin login password"
  type        = string
  sensitive   = true
}