# variables.tf
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name for the EKS cluster."
  type        = string
  default     = "authentik-eks-lab"
}

variable "velero_s3_bucket_prefix" {
  description = "The name for the Velero S3 backup bucket (must be globally unique)."
  type        = string
  default     = "authentik-velero-backups-UNIQUE-SUFFIX" # Will be unique with suffix
}