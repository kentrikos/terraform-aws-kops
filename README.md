# A Terraform module to deploy Kubernetes cluster with kops (beta)


This module will create a Kubernetes cluster with [kops](https://github.com/kubernetes/kops/).

Since it's using `local-exec` to run kops under the hood, it must be run from a host meeting the following requirements:
* kops, kubectl, jq, awscli installed
* permissions to assume cross-account role on target account
* networking access to target account (e.g. via VPC peering) to contact K8s API

Currently it must be run from a host that has networking access to VPC where cluster will be deployed (e.g. from kops management node deployed before-hand).


## Usage:
### cross-account scenario (deploy from "operations" account into "application"):
```hcl
module "kubernetes_cluster_application" {
  source = "https://github.com/kentrikos/terraform-aws-kops.git"

  cluster_name_prefix = "${var.k8s_cluster_name_prefix}"

  region  = "${var.region}"
  vpc_id  = "${var.vpc_id}"
  azs     = "${join(",", var.azs)}"
  subnets = "${join(",", var.k8s_private_subnets)}"

  node_count = "${var.k8s_node_count}"

  iam_cross_account_role_arn = "${var.iam_cross_account_role_arn}"
}
```

### same-account scenario (deploy on "operations" account):
```hcl
module "kubernetes_cluster_operations" {
  source = "https://github.com/kentrikos/terraform-aws-kops.git"

  cluster_name_prefix = "${var.k8s_cluster_name_prefix}"

  region  = "${var.region}"
  vpc_id  = "${var.vpc_id}"
  azs     = "${join(",", var.azs)}"
  subnets = "${join(",", var.k8s_private_subnets)}"
  http_proxy        = "${var.http_proxy}"
  disable_natgw     = "${var.disable_natgw}"

  node_count = "${var.k8s_node_count}"
}
```

### Notes
* cross-account scenario needs minor fixes


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| azs | Availability Zones for the cluster (1 master per AZ will be deployed, only odd numbers are supported) | string | - | yes |
| cluster_name_prefix | Your name of the cluster (without domain which is k8s.local by default) | string | - | yes |
| disable_natgw | Don't use NAT Gateway for egress traffic (may be needed on some accounts) | string | `false` | no |
| http_proxy | IP[:PORT] - address and optional port of HTTP proxy to be used to download packages | string | `` | no |
| iam_cross_account_role_arn | Cross-account role to assume before deploying the cluster | string | `` | no |
| master_instance_type | Instance type (size) for master nodes | string | `m4.large` | no |
| masters_extra_iam_policy_arn | ARN of additional, pre-existing IAM policy with permissions for K8s master instances to be used by kops | string | - | yes |
| masters_iam_policy_arn | ARN of pre-existing IAM policy with permissions for K8s master instances to be used by kops | string | - | yes |
| node_count | Number of worker nodes | string | `1` | no |
| node_instance_type | Instance type (size) for worker nodes | string | `m4.large` | no |
| nodes_iam_policy_arn | ARN of pre-existing IAM policy with permissions for K8s worker instances to be used by kops | string | - | yes |
| region | AWS region | string | - | yes |
| subnets | List of private subnets (matching AZs) where to deploy the cluster) | string | - | yes |
| vpc_id | ID of VPC where cluster will be deployed | string | - | yes |

