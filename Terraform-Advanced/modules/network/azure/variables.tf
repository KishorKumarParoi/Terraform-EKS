variable "name_prefix" {
  description = "Prefix used for Azure network resource names"
  type        = string
}

variable "address_space" {
  description = "Azure VNet address space placeholder"
  type        = list(string)
}

variable "subnets" {
  description = "Azure subnet CIDR blocks placeholder"
  type        = list(string)
}
