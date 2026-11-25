# ---------- Trust GitHub's OIDC token issuer ----------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------- Who may assume the role: only this repo, main branch + PRs ----------
data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:NamanChaturvedii@128036351/eks-gitops-platform@1472288072:ref:refs/heads/main",
        "repo:NamanChaturvedii@128036351/eks-gitops-platform@1472288072:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "github-actions-eks-terraform"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 7200 # 2h: EKS create/destroy takes ~15 min
}

# Terraform creates VPC, EKS, IAM roles, KMS -> needs broad rights (lab).
resource "aws_iam_role_policy_attachment" "github_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
