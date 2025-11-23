#############################################
# 1. S3 Bucket for Velero Backups
#############################################

resource "aws_s3_bucket" "velero_backups" {
  bucket        = "${var.velero_s3_bucket_prefix}-${random_id.suffix.hex}"
  acl           = "private"
  force_destroy = true # Allows Terraform destroy to clean up the bucket contents

  tags = {
    Name = "${var.cluster_name}-velero-backups"
  }
}

#############################################
# 2. IAM Policy for Velero (S3 + EBS)
#############################################

resource "aws_iam_policy" "velero" {
  name        = "${var.cluster_name}-Velero-Policy"
  description = "Policy for Velero backups on EKS (S3 and EBS snapshots)"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # S3 bucket permissions
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ],
        Resource = ["${aws_s3_bucket.velero_backups.arn}/*"]
      },
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = [aws_s3_bucket.velero_backups.arn]
      },

      # EBS snapshot permissions
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ],
        Resource = "*"
      }
    ]
  })
}

#############################################
# 3. IAM Role for Velero (IRSA)
#############################################

data "aws_iam_policy_document" "velero_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      # FIX: Correctly extracts the OIDC URL from the EKS module output
      variable = "${replace(module.eks.oidc_provider[0].url, "https://", "")}:sub" 
      values   = ["system:serviceaccount:velero:velero-server"]
    }

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
  }
}

resource "aws_iam_role" "velero" {
  name               = "${var.cluster_name}-Velero-Role"
  assume_role_policy = data.aws_iam_policy_document.velero_assume.json
}

resource "aws_iam_role_policy_attachment" "velero" {
  policy_arn = aws_iam_policy.velero.arn
  role       = aws_iam_role.velero.name
}

#############################################
# 4. Velero Deployment using Helm (FIXED SYNTAX)
#############################################

resource "helm_release" "velero" {
  depends_on = [
    module.eks,
    aws_iam_role.velero
  ]

  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  namespace        = "velero"
  version          = "5.2.1"
  create_namespace = true

  # FIX: Uses the correct 'set' block argument syntax
  set {
    name  = "configuration.backupStorageLocation.bucket"
    value = aws_s3_bucket.velero_backups.id
  }
  set {
    name  = "configuration.backupStorageLocation.config.region"
    value = var.aws_region
  }

  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-aws"
  }
  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-aws:v1.9.0"
  }

  set {
    name  = "serviceAccount.server.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.velero.arn
  }

  set {
    name  = "snapshotsEnabled"
    value = "true"
  }
  set {
    name  = "defaultVolumeType"
    value = "ebs"
  }
}

#############################################
# 5. Velero Backup Schedule for Authentik
#############################################

resource "kubernetes_manifest" "authentik_daily_schedule" {
  depends_on = [
    helm_release.velero,
    # FIX: Ensure Kubernetes provider is fully authenticated before use
    data.aws_eks_cluster_auth.cluster, 
    module.eks, 
  ]

  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = "authentik-daily"
      namespace = "velero"
    }
    spec = {
      schedule = "0 2 * * *" # Daily @ 2 AM UTC
      template = {
        includedNamespaces = ["authentik"]
        snapshotVolumes    = true
        ttl                = "720h" # 30 days
      }
    }
  }
}