variable "cluster_name_prefix" {
  description = "Your name of the cluster (without domain which is k8s.local by default)"
}

variable "region" {
  description = "AWS region"
}

variable "vpc_id" {
  description = "ID of VPC where cluster will be deployed"
}

variable "azs" {
  description = "Availability Zones for the cluster (1 master per AZ will be deployed, only odd numbers are supported)"
}

variable "subnets" {
  description = "List of private subnets (matching AZs) where to deploy the cluster)"
}

variable "node_count" {
  description = "Number of worker nodes"
  default     = "1"
}

variable "http_proxy" {
  description = "IP[:PORT] - address and optional port of HTTP proxy to be used to download packages"
  default     = ""
}

variable "disable_natgw" {
  description = "Don't use NAT Gateway for egress traffic (may be needed on some accounts)"
  default     = "false"
}

variable "master_instance_type" {
  description = "Instance type (size) for master nodes"
  default     = "m4.large"
}

variable "node_instance_type" {
  description = "Instance type (size) for worker nodes"
  default     = "m4.large"
}

variable "masters_iam_policies_arns" {
  description = "List of existing IAM policies that will be attached to instance profile for master nodes (EC2 instances)"
  type        = "list"
}

variable "nodes_iam_policies_arns" {
  description = "List of existing IAM policies that will be attached to instance profile for worker nodes (EC2 instances)"
  type        = "list"
}

variable "iam_cross_account_role_arn" {
  description = "Cross-account role to assume when deploying the cluster (on another account)"
  default     = ""
}

variable "aws_ssh_keypair_name" {
  description = "Optional name of existing SSH keypair on AWS account, to be used for cluster instances (will be generated if not specified)"
  default     = ""
}

variable "linux_distro" {
  description = "Linux distribution for K8s cluster instances (supported values: debian, amzn2)"
  default     = "debian"
}

variable "enable_module" {
  description = "Controls if the KOPS module will be created (all resources)"
  default     = true
}
