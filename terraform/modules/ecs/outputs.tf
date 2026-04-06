output "cluster_name"       { value = aws_ecs_cluster.main.name }
output "cluster_arn"        { value = aws_ecs_cluster.main.arn }
output "alb_dns_name"       { value = aws_lb.main.dns_name }
output "alb_arn"            { value = aws_lb.main.arn }
output "alb_zone_id"        { value = aws_lb.main.zone_id }
output "service_names"      { value = { for k, v in aws_ecs_service.services : k => v.name } }
output "task_definition_arns" { value = { for k, v in aws_ecs_task_definition.services : k => v.arn } }
output "service_discovery_namespace" { value = aws_service_discovery_private_dns_namespace.main.name }
output "log_group_name"     { value = aws_cloudwatch_log_group.ecs.name }
output "execution_role_arn" { value = aws_iam_role.execution.arn }
output "task_role_arn"      { value = aws_iam_role.task.arn }
