variable "name" {
  description = "Name of the VPC and EKS Cluster"
  default     = "cnpg-on-eks"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-2"
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  default     = "1.25"
  type        = string
}

variable "core_node_group_desired_size" {
  description = "Desired number of nodes in the EKS managed node group"
  default     = 3
  type        = number
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  default     = "10.1.0.0/16"
  type        = string
}

variable "aws_access_key" {
  description = "The AWS Access Key for authentication"
  type        = string
  default     = ""
}

variable "aws_secret_key" {
  description = "The AWS Secret Key for authentication"
  type        = string
  default     = ""
}

variable "kms_key_administrators" {
  description = "A list of IAM ARNs for [key administrators](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators). If no value is provided, the current caller identity is used to ensure at least one key admin is available"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.kms_key_administrators) != 0
    error_message = "List of KMS admins must not be empty."
  }
}
