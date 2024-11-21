terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#=========================================================
# Variables
#=========================================================
variable "github_oidc_provider_arn" {
  type        = string
  description = "GitHub OIDC Provider ARN"
}

variable "github_owner" {
  type        = string
  description = "GitHub リポジトリの所有者"
}

variable "github_repo" {
  type        = string
  description = "GitHub リポジトリの名前"
}

#=========================================================
# ECR Private Repository
#=========================================================
resource "aws_ecr_repository" "main" {
  name                 = "demo-nextjs-app-router-aws-app-runner"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

#=========================================================
# IAM Role for App Runner
#=========================================================
data "aws_iam_policy_document" "apprunner_service_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apprunner.amazonaws.com", "build.apprunner.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "apprunner_ecr_access_role" {
  name               = "apprunner_ecr_access_role"
  assume_role_policy = data.aws_iam_policy_document.apprunner_service_policy.json
}

resource "aws_iam_role_policy_attachment" "apprunner_service_ecr" {
  role       = aws_iam_role.apprunner_ecr_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

##########################################################
# IAM Role for Github OIDC
##########################################################
data "aws_iam_openid_connect_provider" "github" {
  arn = var.github_oidc_provider_arn
}

data "aws_iam_policy_document" "github_oidc_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Role
resource "aws_iam_role" "github_oidc_ecr_access_and_app_runner_deploy_role" {
  name               = "github_oidc_ecr_access_and_app_runner_deploy_role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role_policy.json
}

#--------------------------------------------------------------
# Attach ECR Access Policy
#--------------------------------------------------------------
data "aws_iam_policy_document" "ecr_private_repository_access" {
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [aws_ecr_repository.main.arn] # 必要ならリソースを特定の ECR に限定
  }
}

resource "aws_iam_policy" "ecr_private_repository_access_policy" {
  name   = "ecr_private_repository_access_policy"
  policy = data.aws_iam_policy_document.ecr_private_repository_access.json
}

resource "aws_iam_role_policy_attachment" "name" {
  role       = aws_iam_role.github_oidc_ecr_access_and_app_runner_deploy_role.name
  policy_arn = aws_iam_policy.ecr_private_repository_access_policy.arn
}

#--------------------------------------------------------------
# Attach App Runner Policy
#--------------------------------------------------------------
data "aws_iam_policy_document" "github_oidc_apprunner_with_ecr_deploy_policy_dococument" {
  statement {
    actions = [
      "apprunner:ListServices",
      "apprunner:ListOperations",
      "apprunner:CreateService",
      "apprunner:UpdateService",
      "apprunner:DescribeService",
      "apprunner:TagResource",
      "iam:PassRole",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability"
    ]

    resources = ["*"] # 必要ならリソースを特定の ECR に限定
  }
}

resource "aws_iam_policy" "github_oidc_apprunner_with_ecr_deploy_policy" {
  name   = "github_oidc_apprunner_deploy_policy"
  policy = data.aws_iam_policy_document.github_oidc_apprunner_with_ecr_deploy_policy_dococument.json
}

resource "aws_iam_role_policy_attachment" "github_oidc_apprunner_with_ecr_deploy_policy_attachment" {
  role       = aws_iam_role.github_oidc_ecr_access_and_app_runner_deploy_role.name
  policy_arn = aws_iam_policy.github_oidc_apprunner_with_ecr_deploy_policy.arn
}

#=========================================================
# OUTPUT
#=========================================================

output "ecr_repository_name" {
  value = aws_ecr_repository.main.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.main.repository_url
}

output "ecr_arn" {
  value = aws_ecr_repository.main.arn
}

output "apprunner_access_role_arn" {
  value = aws_iam_role.apprunner_ecr_access_role.arn
}

output "github_assume_role_arn" {
  value = aws_iam_role.github_oidc_ecr_access_and_app_runner_deploy_role.arn
}
