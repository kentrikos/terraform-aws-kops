# IAM CONFIGURATION FOR MASTER INSTANCES:
resource "aws_iam_instance_profile" "masters" {
  name = "k8s_masters_${var.cluster_name_prefix}.k8s.local"
  role = "${aws_iam_role.masters.name}"
}

resource "aws_iam_role" "masters" {
  name = "k8s_masters_${var.cluster_name_prefix}.k8s.local"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "masters" {
  role       = "${aws_iam_role.masters.name}"
  policy_arn = "${var.masters_iam_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "masters_extra" {
  role       = "${aws_iam_role.masters.name}"
  policy_arn = "${var.masters_extra_iam_policy_arn}"
}

# IAM CONFIGURATION FOR WORKER INSTANCES (NODES):
resource "aws_iam_instance_profile" "nodes" {
  name = "k8s_nodes_${var.cluster_name_prefix}.k8s.local"
  role = "${aws_iam_role.nodes.name}"
}

resource "aws_iam_role" "nodes" {
  name = "k8s_nodes_${var.cluster_name_prefix}.k8s.local"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "nodes" {
  role       = "${aws_iam_role.nodes.name}"
  policy_arn = "${var.nodes_iam_policy_arn}"
}

# CLOUDWATCH LOG GROUP:
resource "aws_cloudwatch_log_group" "k8s-cluster" {
  name = "${var.cluster_name_prefix}.k8s.local"
}

# WRAPPER RESOURCE AROUND K8S CLUSTER DEPLOYMENT SCRIPT:
locals {
  option_http_proxy    = "${var.http_proxy    != ""     ? "--http-proxy ${var.http_proxy}" : ""}"
  option_disable_natgw = "${var.disable_natgw == "true" ? "--disable-natgw" : ""}"
}

resource "null_resource" "kubernetes_cluster-cross-account" {
  count      = "${var.iam_cross_account_role_arn != "" ? 1 : 0}"
  depends_on = ["aws_iam_instance_profile.masters", "aws_iam_instance_profile.nodes", "aws_cloudwatch_log_group.k8s-cluster"]

  provisioner "local-exec" {
    command     = "/bin/bash ${path.module}/local-exec/kentrikos_k8s_cluster_deploy.sh --cluster-name-prefix ${var.cluster_name_prefix} --region ${var.region} --vpc-id ${var.vpc_id} --az ${var.azs} --subnets ${var.subnets} --node-count ${var.node_count} --assume-cross-account-role ${var.iam_cross_account_role_arn} --master-instance-type ${var.master_instance_type} --node-instance-type ${var.node_instance_type} --masters-iam-instance-profile-arn ${aws_iam_instance_profile.masters.arn} --nodes-iam-instance-profile-arn ${aws_iam_instance_profile.nodes.arn} --action create ${local.option_http_proxy} ${local.option_disable_natgw}"
    working_dir = "kops"
  }

  provisioner "local-exec" {
    when        = "destroy"
    command     = "/bin/bash ${path.module}/local-exec/kentrikos_k8s_cluster_deploy.sh --cluster-name-prefix ${var.cluster_name_prefix} --region ${var.region} --assume-cross-account-role ${var.iam_cross_account_role_arn} --action destroy"
    working_dir = "kops"
  }
}

resource "null_resource" "kubernetes_cluster-same-account" {
  count      = "${var.iam_cross_account_role_arn != "" ? 0 : 1}"
  depends_on = ["aws_iam_instance_profile.masters", "aws_iam_instance_profile.nodes", "aws_cloudwatch_log_group.k8s-cluster"]

  provisioner "local-exec" {
    command     = "${path.module}/local-exec/kentrikos_k8s_cluster_deploy.sh --cluster-name-prefix ${var.cluster_name_prefix} --region ${var.region} --vpc-id ${var.vpc_id} --az ${var.azs} --subnets ${var.subnets} --node-count ${var.node_count} --master-instance-type ${var.master_instance_type} --node-instance-type ${var.node_instance_type} --masters-iam-instance-profile-arn ${aws_iam_instance_profile.masters.arn} --nodes-iam-instance-profile-arn ${aws_iam_instance_profile.nodes.arn} --action create ${local.option_http_proxy} ${local.option_disable_natgw}"
    working_dir = "kops"
  }

  provisioner "local-exec" {
    when        = "destroy"
    command     = "${path.module}/local-exec/kentrikos_k8s_cluster_deploy.sh --cluster-name-prefix ${var.cluster_name_prefix} --region ${var.region} --action destroy"
    working_dir = "kops"
  }
}
