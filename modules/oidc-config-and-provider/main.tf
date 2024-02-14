resource "rhcs_rosa_oidc_config" "oidc_config" {
  managed = var.managed
  secret_arn = var.managed == false && var.create_unmanaged_oidc_config == true ? (
    module.aws_secrets_manager[0].secret_arn
    ) : (
    var.secret_arn
  )
  issuer_url = var.managed == false && var.create_unmanaged_oidc_config == true ? (
    rhcs_rosa_oidc_config_input.oidc_input[0].issuer_url
    ) : (
    var.issuer_url
  )
  installer_role_arn = var.installer_role_arn
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  url = "https://${rhcs_rosa_oidc_config.oidc_config.oidc_endpoint_url}"

  client_id_list = [
    "openshift",
    "sts.amazonaws.com"
  ]

  tags = var.tags

  thumbprint_list = [rhcs_rosa_oidc_config.oidc_config.thumbprint]
}

module "aws_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = ">=4.1.0"

  count = var.managed == false && var.create_unmanaged_oidc_config == true ? 1 : 0

  bucket = rhcs_rosa_oidc_config_input.oidc_input[count.index].bucket_name
  tags = merge(var.tags, {
    red-hat-managed = true
  })

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false

  attach_policy = true
  policy        = data.aws_iam_policy_document.allow_access_from_another_account[count.index].json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
  count = var.managed == false && var.create_unmanaged_oidc_config == true ? 1 : 0

  statement {
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    sid    = "AllowReadPublicAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]

    resources = [
      format("arn:aws:s3:::%s/*", rhcs_rosa_oidc_config_input.oidc_input[count.index].bucket_name),
    ]
  }
}

resource "rhcs_rosa_oidc_config_input" "oidc_input" {
  count = var.managed == false && var.create_unmanaged_oidc_config == true ? 1 : 0

  region = data.aws_region.current.name
}

module "aws_secrets_manager" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = ">=1.1.1"

  count = var.managed == false && var.create_unmanaged_oidc_config == true ? 1 : 0

  create      = true
  name        = rhcs_rosa_oidc_config_input.oidc_input[count.index].private_key_secret_name
  description = format("Secret for %s", rhcs_rosa_oidc_config_input.oidc_input[count.index].private_key_secret_name)

  tags = merge(var.tags, {
    red-hat-managed = true
  })

  secret_string = rhcs_rosa_oidc_config_input.oidc_input[count.index].private_key
}

resource "aws_s3_object" "discrover_doc_object" {
  count = var.managed == false && var.create_unmanaged_oidc_config == true ? 1 : 0

  bucket       = module.aws_s3_bucket[count.index].s3_bucket_id
  key          = ".well-known/openid-configuration"
  content      = rhcs_rosa_oidc_config_input.oidc_input[count.index].discovery_doc
  content_type = "application/json"

  tags = merge(var.tags, {
    red-hat-managed = true
  })
}

resource "aws_s3_object" "s3_object" {
  count = var.managed == false && var.create_unmanaged_oidc_config == true ? 1 : 0

  bucket       = module.aws_s3_bucket[count.index].s3_bucket_id
  key          = "keys.json"
  content      = rhcs_rosa_oidc_config_input.oidc_input[count.index].jwks
  content_type = "application/json"

  tags = merge(var.tags, {
    red-hat-managed = true
  })
}

data "aws_region" "current" {}

resource "time_sleep" "wait_10_seconds" {
  create_duration  = "10s"
  destroy_duration = "30s"
}

resource "null_resource" "unmanaged_vars_validation" {
  lifecycle {
    precondition {
      condition = (var.managed == true && var.create_unmanaged_oidc_config == null) || (var.managed == false && var.create_unmanaged_oidc_config != null)
      error_message = var.managed == true ? (
        "\"create_unmanaged_oidc_config\" variable should not contain a value when using a managed OIDC provider."
        ) : (
        "\"create_unmanaged_oidc_config\" variable should have a value when using an unmanaged OIDC provider."
      )
    }
    precondition {
      condition = (var.create_unmanaged_oidc_config == false && var.secret_arn != null) || (var.create_unmanaged_oidc_config != false && var.secret_arn == null)
      error_message = var.create_unmanaged_oidc_config == false ? (
        "\"secret_arn\" variable should have a value when using an unmanaged OIDC provider and \"create_unmanaged_oidc_config\" variable is false."
        ) : (
        var.managed == true ? (
          "\"secret_arn\" variable should not contain a value when using a managed OIDC provider."
          ) : (
          "\"secret_arn\" variable should not contain a value when using an unmanaged OIDC provider and \"create_unmanaged_oidc_config\" variable is ${var.create_unmanaged_oidc_config == null ? "null" : var.create_unmanaged_oidc_config}."
        )
      )
    }
    precondition {
      condition = (var.create_unmanaged_oidc_config == false && var.issuer_url != null) || (var.create_unmanaged_oidc_config != false && var.issuer_url == null)
      error_message = var.create_unmanaged_oidc_config == false ? (
        "\"issuer_url\" variable should have a value when using an unmanaged OIDC provider and \"create_unmanaged_oidc_config\" variable is false."
        ) : (
        var.managed == true ? (
          "\"issuer_url\" variable should not contain a value when using a managed OIDC provider."
          ) : (
          "\"issuer_url\" variable should not contain a value when using an unmanaged OIDC provider and \"create_unmanaged_oidc_config\" variable is ${var.create_unmanaged_oidc_config == null ? "null" : var.create_unmanaged_oidc_config}."
        )
      )
    }
    precondition {
      condition = (var.managed == false && var.installer_role_arn != null) || (var.managed != false && var.installer_role_arn == null)
      error_message = var.managed == true ? (
        "\"installer_role_arn\" variable should not contain a value when using a managed OIDC provider."
        ) : (
        "\"installer_role_arn\" variable should have a value when using an unmanaged OIDC provider."
      )
    }
  }
}
