locals {
  cluster_host = try(module.eks.cluster_endpoint, data.aws_eks_cluster.eks.endpoint, null)
  cluster_cert = try(module.eks.cluster_certificate_authority_data, data.aws_eks_cluster.eks.certificate_authority[0].data, null)
}

data "aws_eks_cluster" "eks" {
  name  = module.eks.cluster_endpoint == null ? null : module.eks.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}

provider "aws" {
  region = local.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "kubernetes" {
  host                   = local.cluster_host
  cluster_ca_certificate = base64decode(local.cluster_cert)
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_host
    cluster_ca_certificate = base64decode(local.cluster_cert)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

provider "kubectl" {
  apply_retry_count      = 30
  host                   = local.cluster_host
  cluster_ca_certificate = base64decode(local.cluster_cert)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.eks.token
}
