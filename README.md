# A Terraform module to deploy Kubernetes cluster with kops (beta)


This module will create a Kubernetes cluster with [kops](https://github.com/kubernetes/kops/).

Since it's using `local-exec` to run kops under the hood, it must be run from a host meeting the following requirements:
* kops, kubectl, jq, awscli installed
* apropriate IAM permissions (check https://github.com/kubernetes/kops/blob/master/docs/iam_roles.md + in cross-account scenario permissions to assume cross-account role on target account)
* networking access to target account (e.g. via VPC peering) to contact K8s API

Currently it must be run from a host that has networking access to VPC where cluster will be deployed (e.g. from Jenkins or kops management node deployed before-hand).
This module does not create IAM policies on its own (just roles/instance profiles), instead it expect them to be created beforehand and passed as parameters.


## Usage
### cross-account scenario (deploy from operations into application):
```hcl
module "kubernetes_cluster_application" {
  source = "github.com/kentrikos//terraform-aws-kops"

  cluster_name_prefix        = "${var.product_domain_name}-${var.environment_type}"
  region                     = "${var.region}"
  vpc_id                     = "${var.vpc_id != "" ? var.vpc_id : module.vpc.vpc_id}"
  azs                        = "${join(",", var.azs)}"
  subnets                    = "${join(",", var.k8s_private_subnets)}"

  node_count                 = "${var.k8s_node_count}"
  master_instance_type       = "${var.k8s_master_instance_type}"
  node_instance_type         = "${var.k8s_node_instance_type}"

  masters_iam_policies_arns  = "${var.k8s_masters_iam_policies_arns}"
  nodes_iam_policies_arns    = "${var.k8s_nodes_iam_policies_arns}"

  iam_cross_account_role_arn = "${var.iam_cross_account_role_arn}"
}
```

### same-account scenario (deploy on operations):
```hcl
module "kubernetes_cluster_operations" {
  source = "github.com/kentrikos//terraform-aws-kops"

  cluster_name_prefix  = "${var.product_domain_name}-${var.environment_type}-operations"
  region               = "${var.region}"
  vpc_id               = "${var.vpc_id}"
  azs                  = "${join(",", var.azs)}"
  subnets              = "${join(",", var.k8s_private_subnets)}"
  http_proxy           = "${var.http_proxy}"
  disable_natgw        = "true"

  node_count           = "${var.k8s_node_count}"
  master_instance_type = "${var.k8s_master_instance_type}"
  node_instance_type   = "${var.k8s_node_instance_type}"

  masters_iam_policies_arns  = "${var.k8s_masters_iam_policies_arns}"
  nodes_iam_policies_arns    = "${var.k8s_nodes_iam_policies_arns}"
}
```

### Notes:
* cluster names must be currently globally unique per region (due to kops using S3 bucket for state)


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| azs | Availability Zones for the cluster (1 master per AZ will be deployed, only odd numbers are supported) | string | - | yes |
| cluster_name_prefix | Your name of the cluster (without domain which is k8s.local by default) | string | - | yes |
| disable_natgw | Don't use NAT Gateway for egress traffic (may be needed on some accounts) | string | `false` | no |
| http_proxy | IP[:PORT] - address and optional port of HTTP proxy to be used to download packages | string | `` | no |
| iam_cross_account_role_arn | Cross-account role to assume when deploying the cluster (on another account) | string | `` | no |
| master_instance_type | Instance type (size) for master nodes | string | `m4.large` | no |
| masters_iam_policies_arns | List of existing IAM policies that will be attached to instance profile for master nodes (EC2 instances) | list | - | yes |
| node_count | Number of worker nodes | string | `1` | no |
| node_instance_type | Instance type (size) for worker nodes | string | `m4.large` | no |
| nodes_iam_policies_arns | List of existing IAM policies that will be attached to instance profile for worker nodes (EC2 instances) | list | - | yes |
| region | AWS region | string | - | yes |
| subnets | List of private subnets (matching AZs) where to deploy the cluster) | string | - | yes |
| vpc_id | ID of VPC where cluster will be deployed | string | - | yes |

