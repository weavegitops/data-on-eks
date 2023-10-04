resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

#---------------------------------------------------------------
# IRSA for EBS CSI Driver
#---------------------------------------------------------------
module "ebs_csi_driver_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "~> 5.14"
  create_role           = true
  role_name             = format("%s-%s", local.name, "ebs-csi-driver")
  attach_ebs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  tags = local.tags
}

module "barman_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${random_string.random.result}-cnpg-barman-bucket"

  #acl    = "private"
  ## Disabling the ACL see docs here:
  ## https://go.aws/3EM8hBr

  # For example only - please evaluate for your environment
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

#---------------------------------------------------------------
# IRSA for Barman S3
#---------------------------------------------------------------
module "barman_backup_irsa" {
  source                            = "github.com/aws-ia/terraform-aws-eks-blueprints-addons?ref=ed27abc//modules/irsa"
  eks_cluster_id                    = module.eks.cluster_name
  eks_oidc_provider_arn             = module.eks.oidc_provider_arn
  irsa_iam_policies                 = [aws_iam_policy.cnpg_buckup_policy.arn]
  kubernetes_namespace              = "demo"
  kubernetes_service_account        = "prod"
  create_kubernetes_service_account = false
  create_kubernetes_namespace       = false
}

#---------------------------------------------------------------
# Creates IAM policy for accessing s3 bucket
#---------------------------------------------------------------
resource "aws_iam_policy" "cnpg_buckup_policy" {
  description = "IAM role policy for CloudNativePG Barman Tool"
  name        = "${local.name}-barman-irsa"
  policy      = data.aws_iam_policy_document.cnpg_backup.json
}
