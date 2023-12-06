output "shared_role" {
  description = "Shared Role"
  value       = aws_iam_role.shared_vpc_role.arn
}

output "hosted_zone_id" {
  description = "Hosted Zone ID"
  value       = aws_route53_zone.shared_vpc_hosted_zone.id
}
