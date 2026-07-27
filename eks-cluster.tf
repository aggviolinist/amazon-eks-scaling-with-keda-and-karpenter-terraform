resource "aws_iam_role" "eks-clasta" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.eks-clasta.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "clasta" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks-clasta.arn
  version  = var.kubernetes_version
  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# Tag the cluster's auto-created security group so Karpenter's EC2NodeClass
# can find it later via securityGroupSelectorTerms (mirrors karpenter.sh/discovery
# tagging that eksctl's --tags flag also applies to the cluster SG)

resource "aws_ec2_tag" "cluster_sg_karpenter_discovery" {
  resource_id = aws_eks_cluster.clasta.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# OIDC provider -> required for IRSA (IAM roles for Service Accounts).
# Equivalent of `eksctl utils associate-iam-oidc-provider --cluster ....--approve`

data "tls_certificate" "eks" {
  url = aws_eks_cluster.clasta.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.clasta.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}

# Bootstrap node group -> gives the cluster somewhere to run system pods
# (CoreDNS, the Karpenter controller itself, KEDA operator) before
# Karpenter takes over provisioning workload nodes
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

}

resource "aws_iam_role_policy_attachment" "node-worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node-cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node-ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node-ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_eks_node_group" "bootstrap" {
  cluster_name    = aws_eks_cluster.clasta.name
  node_group_name = "${var.cluster_name}-bootstrap"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }
  depends_on = [
    aws_iam_role_policy_attachment.node-worker,
    aws_iam_role_policy_attachment.node-cni,
    aws_iam_role_policy_attachment.node-ecr,
    aws_iam_role_policy_attachment.node-ssm
  ]

}

## Update an entry in kubeconfig file (~/.kube/config) with the connection details needed to reach your EKS cluster's API server
## -----aws eks update-kubeconfig --name eks-demo-scale --region us-east-1 ------
## -----kubectl get nodes--------
