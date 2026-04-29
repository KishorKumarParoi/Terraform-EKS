output "aws_platform_summary" {
  description = "Summary of the AWS platform entrypoint"
  value = {
    cluster_name = var.cluster_name
    region       = var.aws_region
    cloud        = "aws"
  }
}
