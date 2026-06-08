data "aws_iam_policy_document" "eso_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.app.arn]
  }
}

resource "aws_iam_policy" "eso_secrets" {
  name        = "${local.name}-eso-secrets"
  description = "Allow External Secrets Operator to read todo app secrets"
  policy      = data.aws_iam_policy_document.eso_secrets.json
}

module "eso_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${local.name}-eso"

  role_policy_arns = {
    secrets = aws_iam_policy.eso_secrets.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}
