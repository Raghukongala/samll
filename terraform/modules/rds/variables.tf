variable "project"          { type = string }
variable "env"              { type = string }
variable "vpc_id"           { type = string }
variable "vpc_cidr"         { type = string }
variable "subnet_ids"       { type = list(string) }
variable "db_name"          { type = string; default = "microservices" }
variable "db_username"      { type = string; default = "admin" }
variable "instance_class"   { type = string; default = "db.t3.micro" }
variable "allocated_storage"{ type = number; default = 20 }
variable "multi_az"         { type = bool; default = false }
variable "tags"             { type = map(string); default = {} }
