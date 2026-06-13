output "github_actions_role_arn" {
  description = "Add this to GitHub Actions secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}