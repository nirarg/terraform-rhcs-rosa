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
  aws_account_arn = var.aws_account_arn == null ? data.aws_caller_identity.current[0].arn : var.aws_account_arn
  admin_credentials = var.admin_credentials_username == null && var.admin_credentials_password == null ? (
    null
    ) : (
    { username = var.admin_credentials_username, password = var.admin_credentials_password }
  )
}

resource "rhcs_cluster_rosa_classic" "rosa_classic_cluster" {
  name           = var.cluster_name
  cloud_region   = var.aws_region == null ? data.aws_region.current[0].name : var.aws_region
  aws_account_id = var.aws_account_id == null ? data.aws_caller_identity.current[0].account_id : var.aws_account_id
  replicas       = var.replicas
  version        = var.openshift_version
  sts            = local.sts_roles
  aws_subnet_ids = var.aws_subnet_ids
  availability_zones = length(var.aws_availability_zones) > 0 ? (
    var.aws_availability_zones
    ) : (
    length(var.aws_subnet_ids) > 0 ? (
      distinct(data.aws_subnet.provided_subnet[*].availability_zone)
      ) : (
      slice(data.aws_availability_zones.available[0].names, 0, var.multi_az ? 3 : 1)
    )
  )
  multi_az             = var.multi_az
  admin_credentials    = local.admin_credentials
  autoscaling_enabled  = var.autoscaling_enabled
  base_dns_domain      = var.base_dns_domain
  compute_machine_type = var.compute_machine_type
  worker_disk_size     = var.worker_disk_size
  min_replicas         = var.min_replicas
  max_replicas         = var.max_replicas
  machine_cidr         = var.machine_cidr
  service_cidr         = var.service_cidr
  pod_cidr             = var.pod_cidr
  host_prefix          = var.host_prefix
  default_mp_labels    = var.default_mp_labels
  private_hosted_zone = var.private_hosted_zone_id == null ? null : {
    id       = var.private_hosted_zone_id
    role_arn = var.private_hosted_zone_role_arn
  }
  private          = var.private
  aws_private_link = var.aws_private_link
  proxy = var.http_proxy != null || var.https_proxy != null || var.no_proxy != null || var.additional_trust_bundle != null ? (
    {
      http_proxy              = var.http_proxy
      https_proxy             = var.https_proxy
      no_proxy                = var.no_proxy
      additional_trust_bundle = var.additional_trust_bundle
    }
    ) : (
    null
  )
  ec2_metadata_http_tokens = var.ec2_metadata_http_tokens

  properties = merge(
    {
      rosa_creator_arn = local.aws_account_arn
    },
    var.properties
  )
  tags = var.tags

  aws_additional_compute_security_group_ids       = var.aws_additional_compute_security_group_ids
  aws_additional_infra_security_group_ids         = var.aws_additional_infra_security_group_ids
  aws_additional_control_plane_security_group_ids = var.aws_additional_control_plane_security_group_ids

  kms_key_arn                  = var.kms_key_arn
  wait_for_create_complete     = var.wait_for_create_complete
  disable_scp_checks           = var.disable_scp_checks
  disable_workload_monitoring  = var.disable_workload_monitoring
  etcd_encryption              = var.etcd_encryption
  fips                         = var.fips
  disable_waiting_in_destroy   = var.disable_waiting_in_destroy
  destroy_timeout              = var.destroy_timeout
  upgrade_acknowledgements_for = var.upgrade_acknowledgements_for
}

data "aws_caller_identity" "current" {
  count = var.aws_account_id == null || var.aws_account_arn == null ? 1 : 0
}

data "aws_region" "current" {
  count = var.aws_region == null ? 1 : 0
}

data "aws_availability_zones" "available" {
  count = length(var.aws_availability_zones) > 0 ? 0 : 1

  state = "available"

  # New configuration to exclude Local Zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_subnet" "provided_subnet" {
  count = length(var.aws_subnet_ids)

  id = var.aws_subnet_ids[count.index]
}
