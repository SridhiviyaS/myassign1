data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config {
    subnet_ids = concat(var.private_subnets, var.public_subnets)
  }
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "node_group" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "node_group_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])
  policy_arn = each.value
  role       = aws_iam_role.node_group.name
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnets
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  instance_types = ["t3.medium"]
  depends_on = [
    aws_iam_role_policy_attachment.node_group_policies
  ]
}

# aws-auth ConfigMap to allow Jenkins IAM role to access the cluster
resource "null_resource" "aws_auth" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.main.name}
      kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.node_group.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${var.jenkins_role_arn}
      username: jenkins
      groups:
        - system:masters
EOF
    EOT
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]
}

# Get current AWS region
data "aws_region" "current" {}