variable "name_prefix" {
  description = "Prefix used for shared security objects"
  type        = string
}

variable "common_tags" {
  description = "Common tags shared by security modules"
  type        = map(string)
  default     = {}
}
