locals {
  name   = var.name
  region = var.region

  azs = slice(data.aws_availability_zones.available.names, 0, length(data.aws_availability_zones.available.names))

  admin_roles = [ for role in toset(var.admin_role_arns) : {
      rolearn  = role
      username = "Administrator"
      groups   = [ "system:masters" ]
    }
  ]

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/awslabs/data-on-eks"
  }
}
