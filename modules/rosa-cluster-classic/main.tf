data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  sts_roles = {
    role_arn         = var.installer_role_arn,
    support_role_arn = var.support_role_arn,
    instance_iam_roles = {
      master_role_arn = var.controlplane_role_arn,
      worker_role_arn = var.worker_role_arn
    },
    operator_role_prefix = var.operator_role_prefix,
    oidc_config_id       = var.oidc_config_id
  }
  private_hosted_zone = var.private_hosted_zone_id == null ? null : {
    id       = var.private_hosted_zone_id
    role_arn = var.private_hosted_zone_role_arn
  }
}

data "aws_subnet" "provided_subnet" {
  count = length(var.aws_subnet_ids)

  id = var.aws_subnet_ids[count.index]
}

resource "rhcs_cluster_rosa_classic" "rosa_sts_cluster" {
  name           = var.cluster_name
  cloud_region   = data.aws_region.current.name
  aws_account_id = data.aws_caller_identity.current.account_id
  replicas       = var.replicas
  version        = var.openshift_version
  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }
  sts                = local.sts_roles
  aws_subnet_ids     = var.aws_subnet_ids
  availability_zones = distinct(data.aws_subnet.provided_subnet[*].availability_zone)
  // aws_private_link   = var.aws_private_link
  // private            = var.private
  multi_az             = var.multi_az
  admin_credentials    = var.admin_credentials
  autoscaling_enabled  = var.autoscaling_enabled
  base_dns_domain      = var.base_dns_domain
  private_hosted_zone  = local.private_hosted_zone
  compute_machine_type = var.compute_machine_type
  min_replicas         = var.min_replicas
  max_replicas         = var.max_replicas


  wait_for_create_complete = true
}
