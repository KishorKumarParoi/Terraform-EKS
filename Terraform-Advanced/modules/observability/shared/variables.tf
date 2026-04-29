variable "cluster_name" {
  description = "Cluster name for observability resources"
  type        = string
}

variable "log_retention_days" {
  description = "Retention days for logs and metrics"
  type        = number
  default     = 7
}
