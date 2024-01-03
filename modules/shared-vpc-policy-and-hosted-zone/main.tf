locals {
  name_prefix = var.name_prefix != null ? var.name_prefix : var.cluster_name
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role" "shared_vpc_role" {
  name = "${local.name_prefix}-shared-vpc-role"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ResourceGroupsandTagEditorFullAccess"
  ]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = [
            var.ingress_operator_role_arn,
            var.installer_role_arn
          ]
        }
      }
    ]
  })
  description = "Role that will be assumed from the Target AWS account where the cluster resides"
}

resource "aws_iam_policy" "shared_vpc_policy" {
  name = "${local.name_prefix}-shared-vpc-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:ChangeTagsForResource",
          "route53:GetAccountLimit",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListTagsForResource",
          "route53:UpdateHostedZoneComment",
          "tag:GetResources",
          "tag:UntagResources"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "shared_vpc_role_policy_attachment" {
  role       = aws_iam_role.shared_vpc_role.name
  policy_arn = aws_iam_policy.shared_vpc_policy.arn
}

resource "aws_ram_resource_share" "shared_vpc_resource_share" {
  name                      = "${local.name_prefix}-shared-vpc-resource-share"
  allow_external_principals = true
}

resource "aws_ram_principal_association" "shared_vpc_resource_share" {
  principal          = var.target_aws_account
  resource_share_arn = aws_ram_resource_share.shared_vpc_resource_share.arn
}

# resource "aws_ram_sharing_with_organization" "shared_vpc_resource_share" {}

resource "aws_ram_resource_association" "shared_vpc_resource_association" {
  count = length(var.subnets)

  resource_arn       = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.subnets[count.index]}"
  resource_share_arn = aws_ram_resource_share.shared_vpc_resource_share.arn
}

resource "aws_route53_zone" "shared_vpc_hosted_zone" {
  name = "${var.cluster_name}.${var.hosted_zone_base_domain}"

  vpc {
    vpc_id = var.vpc_id
  }
}
