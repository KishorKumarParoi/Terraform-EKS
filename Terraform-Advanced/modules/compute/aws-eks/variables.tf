variable "cluster_name" {
  description = "AWS EKS cluster name placeholder"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version placeholder for AWS EKS"
  type        = string
}

variable "node_instance_types" {
  description = "Worker node instance type list"
  type        = list(string)
}
