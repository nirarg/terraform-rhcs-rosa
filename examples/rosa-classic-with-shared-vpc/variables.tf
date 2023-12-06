variable "cluster_name" {
  type = string
}

variable "shared_vpc_aws_key" {
  type = string
}

variable "shared_vpc_aws_secret" {
  type = string
}

variable "shared_vpc_aws_region" {
  type = string
}

variable "shared_vpc_aws_account" {
  type = string
}

variable "shared_vpc_role_name" {
  type    = string
  default = null
}

variable "openshift_version" {
  type    = string
  default = "4.13"
}

variable "account_role_prefix" {
  type    = string
  default = null
}

variable "operator_role_prefix" {
  type    = string
  default = null
}
