variable "name_prefix" {
  description = "Prefix used for AWS network resource names"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block placeholder for the AWS network module"
  type        = string
}

variable "subnet_count" {
  description = "Number of subnets the module should represent"
  type        = number
}

variable "availability_zones" {
  description = "Availability zones assigned to the network module"
  type        = list(string)
}
