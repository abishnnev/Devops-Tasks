output "kubeconfig_command" {
  description = "Command to run to update your kubeconfig file"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "nginx_ingress_hostname" {
  description = "AWS NLB DNS name created by NGINX Ingress Controller"
  value = try(
    data.kubernetes_service.nginx_controller_service.status.0.load_balancer.0.ingress.0.hostname,
    ""
  )
}

output "velero_bucket_name" {
  description = "The S3 bucket where Velero stores its backups."
  value       = aws_s3_bucket.velero_backups.id
}
