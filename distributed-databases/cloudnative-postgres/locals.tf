locals {
  name   = var.name
  region = var.region

  azs = slice(data.aws_availability_zones.available.names, 0, length(data.aws_availability_zones.available.names) - 1)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/awslabs/data-on-eks"
  }
}
