module "eks_blueprints_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.32.1"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  #---------------------------------------------------------------
  # Amazon EKS Managed Add-ons
  #---------------------------------------------------------------
  # EKS Addons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  #---------------------------------------------------------------
  # Metrics Server
  #---------------------------------------------------------------
  enable_metrics_server = true

  #---------------------------------------------------------------
  # Cluster Autoscaler
  #---------------------------------------------------------------
  enable_cluster_autoscaler = true

  #---------------------------------------------------------------
  # Spark Operator Add-on
  #---------------------------------------------------------------
  enable_spark_k8s_operator = true

  #---------------------------------------------------------------
  # Apache YuniKorn Add-on
  #---------------------------------------------------------------
  enable_yunikorn = true
  #---------------------------------------------------------------
  # Argo Events Add-on
  #---------------------------------------------------------------
  enable_argo_workflows = true
  #---------------------------------------
  # Amazon Managed Prometheus
  #---------------------------------------
  enable_amazon_prometheus             = true
  amazon_prometheus_workspace_endpoint = aws_prometheus_workspace.amp.prometheus_endpoint
  #---------------------------------------
  # Prometheus Server Add-on
  #---------------------------------------
  enable_prometheus = true
  prometheus_helm_config = {
    name       = "prometheus"
    repository = "https://prometheus-community.github.io/helm-charts"
    chart      = "prometheus"
    version    = "15.10.1"
    namespace  = "prometheus"
    timeout    = "300"
    values = [
      templatefile("${path.module}/helm-values/prometheus-values.yaml", {
        operating_system = "linux"
      })
    ]
  }
  #---------------------------------------
  # AWS for FluentBit - DaemonSet
  #---------------------------------------
  enable_aws_for_fluentbit                 = true
  aws_for_fluentbit_cw_log_group_name      = "/${var.name}/fluentbit-logs" # Optional
  aws_for_fluentbit_cw_log_group_retention = 30
  aws_for_fluentbit_helm_config = {
    name       = "aws-for-fluent-bit"
    chart      = "aws-for-fluent-bit"
    repository = "https://aws.github.io/eks-charts"
    version    = "0.1.21"
    namespace  = "aws-for-fluent-bit"
    values = [
      templatefile("${path.module}/helm-values/aws-for-fluentbit-values.yaml", {
        region               = var.region,
        cloudwatch_log_group = "/${var.name}/fluentbit-logs"
      })
    ]
  }
}
#---------------------------------------------------------------
# Kubernetes Cluster role for argo workflows to run spark jobs
#---------------------------------------------------------------
resource "kubernetes_cluster_role" "spark_op_role" {
  metadata {
    name = "spark-op-role"
  }

  rule {
    verbs      = ["*"]
    api_groups = ["sparkoperator.k8s.io"]
    resources  = ["sparkapplications"]
  }
}
#---------------------------------------------------------------
# Kubernetes Role binding role for argo workflows/data-team-a
#---------------------------------------------------------------
resource "kubernetes_role_binding" "spark_role_binding" {
  metadata {
    name      = "data-team-a-spark-rolebinding"
    namespace = "data-team-a"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "argo-workflows"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.spark_op_role.id
  }
}
resource "kubernetes_role_binding" "admin_rolebinding_argoworkflows" {
  metadata {
    name      = "argo-workflows-admin-rolebinding"
    namespace = "argo-workflows"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "argo-workflows"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }
}
resource "kubernetes_role_binding" "admin_rolebinding_data_teama" {
  metadata {
    name      = "data-team-a-admin-rolebinding"
    namespace = "data-team-a"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "data-team-a"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }
}

#---------------------------------------------------------------
# IRSA for Argo events to read SQS
#---------------------------------------------------------------
module "irsa_argo_events" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa?ref=v4.32.1"

  create_kubernetes_namespace = true
  kubernetes_namespace        = "argo-events"
  kubernetes_service_account  = "event-sa"
  irsa_iam_policies           = [data.aws_iam_policy.sqs.arn]
  eks_cluster_id              = module.eks_blueprints.eks_cluster_id
  eks_oidc_provider_arn       = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks_blueprints.oidc_provider}"
}

data "aws_iam_policy" "sqs" {
  name = "AmazonSQSReadOnlyAccess"
}
