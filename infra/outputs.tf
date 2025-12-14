# output "vpc_id" {
#   value = module.vpc.vpc_id
# }

# output "eks_cluster_name" {
#   value = module.eks.cluster_name
# }

output "data_bucket_name" {
  value = module.data_bucket.bucket_name
}
output "ingest_api_iam_access_key_id" {
  value     = module.data_bucket.iam_access_key_id
  sensitive = true
}
output "ingest_api_iam_access_key" {
  value     = module.data_bucket.iam_secret_access_key
  sensitive = true
}
