output "operator_role_prefix" {
  value = var.operator_role_prefix
}

output "operator_roles_arn" {
  value = { for idx, value in aws_iam_role.operator_role : data.rhcs_rosa_operator_roles.operator_roles.operator_iam_roles[idx].operator_name => value.arn }
}
