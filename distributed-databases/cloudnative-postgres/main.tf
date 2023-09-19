module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  cluster_name    = local.name
  cluster_version = var.eks_cluster_version

  cluster_endpoint_private_access = true # if true, Kubernetes API requests within your cluster's VPC (such as node to control plane communication) use the private VPC endpoint
  cluster_endpoint_public_access  = true # if true, Your cluster API server is accessible from the internet. You can, optionally, limit the CIDR blocks that can access the public endpoint.

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  manage_aws_auth_configmap = true
  #create_aws_auth_configmap = false

  aws_auth_roles = [
    # We need to add the Administrator Role
    {
      rolearn = "arn:aws:iam::482649550366:role/AdministratorAccess"
      username = "Administrator"
      groups = [
        "system:masters",
      ]
    }
  ]

  #---------------------------------------
  # Note: This can further restricted to specific required for each Add-on and your application
  #---------------------------------------
  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Allows Control Plane Nodes to talk to Worker nodes on all ports. Added this to simplify the example and further avoid issues with Add-ons communication with Control plane.
    # This can be restricted further to specific port based on the requirement for each Add-on e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  eks_managed_node_group_defaults = {
    # NVMe instance store volumes are automatically enumerated and assigned a device
    pre_bootstrap_user_data = <<-EOT
      cat <<-EOF > /etc/profile.d/bootstrap.sh
      #!/bin/sh

      # Configure NVMe volumes in RAID0 configuration
      # https://github.com/awslabs/amazon-eks-ami/blob/056e31f8c7477e893424abce468cb32bbcd1f079/files/bootstrap.sh#L35C121-L35C126
      # Mount will be: /mnt/k8s-disks
      export LOCAL_DISKS='raid0'
      EOF

      # Source extra environment variables in bootstrap script
      sed -i '/^set -o errexit/a\\nsource /etc/profile.d/bootstrap.sh' /etc/eks/bootstrap.sh
    EOT

    ebs_optimized = true
    # This bloc device is used only for root volume. Adjust volume according to your size.
    # NOTE: Don't use this volume for Spark workloads
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size = 100
          volume_type = "gp3"
        }
      }
    }
  }

  eks_managed_node_groups = {
    core_node_group = {
      name        = "core-node-group"
      description = "EKS managed node group example launch template"
      # Filtering only Secondary CIDR private subnets starting with "100.". Subnet IDs where the nodes/node groups will be provisioned

      ami_id = data.aws_ami.eks.image_id
      # This will ensure the bootstrap user data is used to join the node
      # By default, EKS managed node groups will not append bootstrap script;
      # this adds it back in using the default template provided by the module
      # Note: this assumes the AMI provided is an EKS optimized AMI derivative
      enable_bootstrap_user_data = true

      # Optional - This is to show how you can pass pre bootstrap data
      pre_bootstrap_user_data = <<-EOT
        echo "Node bootstrap process started by Data on EKS"
      EOT

      # Optional - Post bootstrap data to verify anything
      post_bootstrap_user_data = <<-EOT
        echo "Bootstrap complete.Ready to Go!"
      EOT

      subnet_ids = module.vpc.private_subnets

      min_size     = 1
      max_size     = 9
      desired_size = 1

      force_update_version = true
      instance_types       = ["m5.xlarge"]

      labels = {
        WorkerType    = "ON_DEMAND"
        NodeGroupType = "core"
      }

    }
  }

  # eks_managed_node_group_defaults = {
  #   iam_role_additional_policies = {
  #     # Not required, but used in the example to access the nodes to inspect mounted volumes
  #     AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  #   }
  # }

}

locals {

  # node_iam_role_arns = concat([for group in module.eks_managed_node_groups : group.iam_role_arn])

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::482649550366:role/AdministratorAccess"
      username = "Administrator"
      groups   = ["system:masters"]
    },
  ]

  # aws_auth_configmap_data = {
  #   mapRoles = yamlencode(concat(
  #     [for role_arn in local.node_iam_role_arns : {
  #       rolearn  = role_arn
  #       username = "system:node:{{EC2PrivateDNSName}}"
  #       groups = [
  #         "system:bootstrappers",
  #         "system:nodes",
  #       ]
  #       }
  #     ],
  #     local.aws_auth_roles
  #   ))
  #   # mapUsers    = yamlencode(local.aws_auth_roles)
  #   # mapAccounts = yamlencode(var.aws_auth_accounts)
  #   mapUsers    = yamlencode({})
  #   mapAccounts = yamlencode({})
  # }

  # aws_auth_configmap = {
  #   apiVersion = "v1"
  #   kind = "ConfigMap"
  #   metadata = {
  #     name = "aws-auth"
  #     namespace = "kube-system"
  #   }
  #   data = local.aws_auth_configmap_data
  # }

  # eks_managed_node_groups = {

  #   doeks_node_group = {
  #     name        = "doeks-node-group"
  #     description = "EKS managed node group example launch template"

  #     ami_id = data.aws_ami.eks.image_id
  #     # This will ensure the bootstrap user data is used to join the node
  #     # By default, EKS managed node groups will not append bootstrap script;
  #     # this adds it back in using the default template provided by the module
  #     # Note: this assumes the AMI provided is an EKS optimized AMI derivative
  #     enable_bootstrap_user_data = true

  #     # Optional - This is to show how you can pass pre bootstrap data
  #     pre_bootstrap_user_data = <<-EOT
  #       echo "Node bootstrap process started by Data on EKS"
  #     EOT

  #     # Optional - Post bootstrap data to verify anything
  #     post_bootstrap_user_data = <<-EOT
  #       echo "Bootstrap complete.Ready to Go!"
  #     EOT

  #     subnet_ids = module.vpc.private_subnets

  #     min_size     = 1
  #     max_size     = 9
  #     desired_size = 1

  #     force_update_version = true
  #     instance_types       = ["m5.xlarge"]

  #     ebs_optimized = true
  #     block_device_mappings = {
  #       xvda = {
  #         device_name = "/dev/xvda"
  #         ebs = {
  #           volume_size = 100
  #           volume_type = "gp3"
  #         }
  #       }
  #     }

  #     labels = {
  #       WorkerType    = "ON_DEMAND"
  #       NodeGroupType = "doeks"
  #     }

  #     tags = {
  #       Name = "doeks-node-grp"
  #     }
  #   }
  # }
}

# module "eks_managed_node_groups" {

#   source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
#   version = "~> 19"

#   for_each = local.eks_managed_node_groups

#   name            = each.value.name
#   cluster_name    = module.eks.cluster_name
#   cluster_version = module.eks.cluster_version

#   ami_id          = each.value.ami_id

#   enable_bootstrap_user_data = true

#   subnet_ids      = each.value.subnet_ids

#   // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
#   // Without it, the security groups of the nodes are empty and thus won't join the cluster.
#   cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
#   vpc_security_group_ids            = [module.eks.node_security_group_id]

#   min_size     = each.value.min_size
#   max_size     = each.value.max_size
#   desired_size = each.value.desired_size

#   instance_types = each.value.instance_types

#   labels = contains(keys(each.value), "labels") ? each.value.labels : {}
#   taints = contains(keys(each.value), "taints") ? each.value.taints : []
#   tags   = contains(keys(each.value), "tags") ? each.value.tags : {}

#   # depends_on = [ kubectl_manifest.aws_auth_configmap ]

# }

# resource "kubectl_manifest" "aws_auth_configmap" {
#   yaml_body = yamlencode(local.aws_auth_configmap)

#   force_conflicts = true
# }
