# ── GitHub Actions OIDC provider ──────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "Terraform"
  }
}

# ── Trust policy — only this specific repo can assume the role ────────────
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    # Restrict to specific repo and any branch/tag/PR
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── GitHub Actions deploy role ────────────────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name               = "GitHubActionsDeployRole"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
  tags = {
    Name      = "GitHubActionsDeployRole"
    ManagedBy = "Terraform"
  }
}

# ── Admin access — management account orchestrates cross-account deploys ──
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}