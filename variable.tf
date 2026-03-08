variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to nodes (optional)"
  type        = string
  default     = ""
  
  validation {
    condition     = var.ssh_key_name == "" || can(regex("^[a-zA-Z0-9_-]+$", var.ssh_key_name))
    error_message = "SSH key name must contain only alphanumeric characters, hyphens, and underscores."
  }
}
