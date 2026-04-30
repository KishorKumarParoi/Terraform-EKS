output "aws_artifact_bucket" {
  value = module.aws_base.artifact_bucket_name
}

output "azure_resource_group" {
  value = module.azure_base.resource_group_name
}

output "gcp_artifact_bucket" {
  value = module.gcp_base.artifact_bucket_name
}
