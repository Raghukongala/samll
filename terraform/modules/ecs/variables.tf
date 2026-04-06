variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecr_base" {
  type        = string
  description = "Base ECR URL, e.g. 123456789.dkr.ecr.ap-south-1.amazonaws.com/myapp/dev"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "tags" {
  type    = map(string)
  default = {}
}
