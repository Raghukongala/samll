variable "project"            { type = string }
variable "env"                { type = string }
variable "vpc_id"             { type = string }
variable "subnet_ids"         { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "kubernetes_version" { type = string; default = "1.29" }
variable "instance_types"     { type = list(string); default = ["t3.medium"] }
variable "desired_nodes"      { type = number; default = 2 }
variable "min_nodes"          { type = number; default = 1 }
variable "max_nodes"          { type = number; default = 5 }
variable "tags"               { type = map(string); default = {} }
