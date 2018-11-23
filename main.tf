# Generic IAM assume role policy for EC2:
data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM CONFIGURATION FOR MASTER INSTANCES:
resource "aws_iam_instance_profile" "masters" {
  name = "k8s_masters_${var.cluster_name_prefix}.k8s.local"
  role = "${aws_iam_role.masters.name}"
}

resource "aws_iam_role" "masters" {
  name = "k8s_masters_${var.cluster_name_prefix}.k8s.local"
  path = "/"

  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}

resource "aws_iam_role_policy_attachment" "masters" {
  role       = "${aws_iam_role.masters.name}"
  count      = "${length(var.masters_iam_policies_arns)}"
  policy_arn = "${var.masters_iam_policies_arns[count.index]}"
}

# IAM CONFIGURATION FOR WORKER INSTANCES (NODES):
resource "aws_iam_instance_profile" "nodes" {
  name = "k8s_nodes_${var.cluster_name_prefix}.k8s.local"
  role = "${aws_iam_role.nodes.name}"
}

resource "aws_iam_role" "nodes" {
  name = "k8s_nodes_${var.cluster_name_prefix}.k8s.local"
  path = "/"

  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}

resource "aws_iam_role_policy_attachment" "nodes" {
  role       = "${aws_iam_role.nodes.name}"
  count      = "${length(var.nodes_iam_policies_arns)}"
  policy_arn = "${var.nodes_iam_policies_arns[count.index]}"
}

# CLOUDWATCH LOG GROUP:
resource "aws_cloudwatch_log_group" "k8s-cluster" {
  name = "${var.cluster_name_prefix}.k8s.local"
}

# WRAPPER RESOURCE AROUND K8S CLUSTER DEPLOYMENT SCRIPT:
locals {
  option_http_proxy                = "${var.http_proxy    != ""     ? "--http-proxy ${var.http_proxy}" : ""}"
  option_disable_natgw             = "${var.disable_natgw == "true" ? "--disable-natgw" : ""}"
  option_assume_cross_account_role = "${var.iam_cross_account_role_arn != "" ? "--assume-cross-account-role ${var.iam_cross_account_role_arn}" : ""}"
}

resource "null_resource" "kubernetes_cluster" {
  depends_on = ["aws_iam_instance_profile.masters", "aws_iam_instance_profile.nodes", "aws_cloudwatch_log_group.k8s-cluster"]

  provisioner "local-exec" {
    command = <<EOT
      /bin/bash \
      ${path.module}/local-exec/kentrikos_k8s_cluster_deploy.sh \
      --action create \
      --cluster-name-prefix ${var.cluster_name_prefix} \
      --region ${var.region} \
      --vpc-id ${var.vpc_id} \
      --az ${var.azs} \
      --subnets ${var.subnets} \
      --node-count ${var.node_count} \
      --master-instance-type ${var.master_instance_type} \
      --node-instance-type ${var.node_instance_type} \
      --masters-iam-instance-profile-arn ${aws_iam_instance_profile.masters.arn} \
      --nodes-iam-instance-profile-arn ${aws_iam_instance_profile.nodes.arn} \
      ${local.option_assume_cross_account_role} \
      ${local.option_http_proxy} \
      ${local.option_disable_natgw}
EOT

    working_dir = "kops"
  }

  provisioner "local-exec" {
    when = "destroy"

    command = <<EOT
      /bin/bash \
      ${path.module}/local-exec/kentrikos_k8s_cluster_deploy.sh \
      --action destroy \
      --cluster-name-prefix ${var.cluster_name_prefix} \
      --region ${var.region} \
      ${local.option_assume_cross_account_role}
EOT

    working_dir = "kops"
  }
}
