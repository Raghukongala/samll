output "alb_url"              { value = "http://${module.ecs.alb_dns_name}" }
output "cluster_name"         { value = module.ecs.cluster_name }
output "ecr_repository_urls"  { value = module.ecr.repository_urls }
output "log_group"            { value = module.ecs.log_group_name }
output "service_discovery_ns" { value = module.ecs.service_discovery_namespace }
