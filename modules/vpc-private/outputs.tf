output "private_subnets" {
  value = module.vpc.private_subnets
}

output "availability_zones" {
  value = local.azs
}
