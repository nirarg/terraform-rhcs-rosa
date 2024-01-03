provider "aws" {
  alias = "shared-vpc"

  access_key = var.shared_vpc_aws_key
  secret_key = var.shared_vpc_aws_secret
  region     = var.shared_vpc_aws_region
}

############################
# VPC
############################
module "vpc" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.shared-vpc
  }

  name_prefix  = var.cluster_name
  subnet_count = var.replicas
}

locals {
  account_role_prefix  = var.account_role_prefix != null ? var.account_role_prefix : "${var.cluster_name}-account"
  shared_vpc_role_name = var.shared_vpc_role_name != null ? var.shared_vpc_role_name : "${var.cluster_name}-shared-vpc-role"
  operator_role_prefix = var.operator_role_prefix != null ? var.operator_role_prefix : "${var.cluster_name}-operator"
}

##############################################################
# Account roles includes IAM roles and IAM policies
##############################################################
module "account_iam_resources" {
  source = "../../modules/account-iam-resources"

  account_role_prefix = local.account_role_prefix
  openshift_version   = var.openshift_version
}

############################
# operator policies
############################
module "operator_policies" {
  source = "../../modules/operator-policies"

  account_role_prefix = module.account_iam_resources.account_role_prefix
  openshift_version   = module.account_iam_resources.openshift_version
  shared_vpc_role_arn = "arn:aws:iam::${var.shared_vpc_aws_account}:role/${local.shared_vpc_role_name}"
}

############################
# OIDC provider
############################
module "oidc_provider" {
  source = "../../modules/oidc-provider"

  managed = true
}

############################
# operator roles
############################
module "operator_roles" {
  source = "../../modules/operator-roles"
  # adding a dependency to operator_policies module
  depends_on = [module.operator_policies]

  operator_role_prefix = local.operator_role_prefix

  account_role_prefix = module.operator_policies.account_role_prefix
  path                = module.account_iam_resources.path
  oidc_endpoint_url   = module.oidc_provider.oidc_endpoint_url
}

resource "rhcs_dns_domain" "dns_domain" {}

############################
# shared-vpc-policy-and-hosted-zone
############################
data "aws_caller_identity" "current" {}

module "shared-vpc-policy-and-hosted-zone" {
  source = "../../modules/shared-vpc-policy-and-hosted-zone"

  providers = {
    aws = aws.shared-vpc
  }

  cluster_name              = var.cluster_name
  target_aws_account        = data.aws_caller_identity.current.account_id
  installer_role_arn        = module.account_iam_resources.account_roles_arn["Installer"]
  ingress_operator_role_arn = module.operator_roles.operator_roles_arn["openshift-ingress-operator"]
  subnets                   = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  hosted_zone_base_domain   = rhcs_dns_domain.dns_domain.id
  vpc_id                    = module.vpc.vpc_id
}

############################
# ROSA STS cluster
############################
module "rosa_cluster_classic" {
  source = "../../modules/rosa-cluster-classic"

  cluster_name          = var.cluster_name
  operator_role_prefix  = module.operator_roles.operator_role_prefix
  openshift_version     = var.openshift_version
  replicas              = var.replicas
  installer_role_arn    = module.account_iam_resources.account_roles_arn["Installer"]
  support_role_arn      = module.account_iam_resources.account_roles_arn["Support"]
  controlplane_role_arn = module.account_iam_resources.account_roles_arn["ControlPlane"]
  worker_role_arn       = module.account_iam_resources.account_roles_arn["Worker"]
  oidc_config_id        = module.oidc_provider.oidc_config_id
  aws_subnet_ids        = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  //aws_private_link      = true
  //private               = true
  multi_az                     = true
  admin_credentials            = { username = "admin1", password = "123456!qwertyU" }
  compute_machine_type         = var.machine_type
  base_dns_domain              = rhcs_dns_domain.dns_domain.id
  private_hosted_zone_id       = module.shared-vpc-policy-and-hosted-zone.hosted_zone_id
  private_hosted_zone_role_arn = module.shared-vpc-policy-and-hosted-zone.shared_role
}
