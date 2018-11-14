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
  default = "1"
}

variable "iam_cross_account_role_arn" {
  description = "Cross-account role to assume before deploying the cluster"
  default = ""
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

variable "masters_iam_policy_arn" {
  description = "ARN of pre-existing IAM policy with permissions for K8s master instances to be used by kops"
}

variable "masters_extra_iam_policy_arn" {
  description = "ARN of additional, pre-existing IAM policy with permissions for K8s master instances to be used by kops"
}

variable "nodes_iam_policy_arn" {
  description = "ARN of pre-existing IAM policy with permissions for K8s worker instances to be used by kops"
}
