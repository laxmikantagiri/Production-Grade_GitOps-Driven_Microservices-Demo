# ── Cluster IAM Role ─────────────────────────────────────────────────────────
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = { Name = "${var.cluster_name}-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── Node IAM Role ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "nodes" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = { Name = "${var.cluster_name}-node-role" }
}

resource "aws_iam_role_policy_attachment" "nodes_worker"   { role = aws_iam_role.nodes.name; policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" }
resource "aws_iam_role_policy_attachment" "nodes_ecr"      { role = aws_iam_role.nodes.name; policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" }
resource "aws_iam_role_policy_attachment" "nodes_cni"      { role = aws_iam_role.nodes.name; policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" }

# ── Node Security Group ───────────────────────────────────────────────────────
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress { description = "Node-to-node"             from_port = 0;     to_port = 0;     protocol = "-1"; self = true }
  ingress { description = "Control plane to nodes"   from_port = 443;   to_port = 443;   protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "Kubelet"                  from_port = 10250; to_port = 10250; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { description = "All outbound"             from_port = 0;     to_port = 0;     protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.cluster_name}-nodes-sg" }
}

# ── KMS Key for secrets encryption ───────────────────────────────────────────
resource "aws_kms_key" "eks" {
  description             = "EKS secrets encryption for ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "${var.cluster_name}-eks-key" }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.nodes.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  encryption_config {
    resources = ["secrets"]
    provider  { key_arn = aws_kms_key.eks.arn }
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
  tags       = { Name = var.cluster_name }
}

# ── OIDC Provider (required for IRSA) ────────────────────────────────────────
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  tags            = { Name = "${var.cluster_name}-oidc" }
}

# ── Managed Node Group ────────────────────────────────────────────────────────
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  disk_size       = 20

  scaling_config { min_size = 2; max_size = 4; desired_size = 2 }
  update_config  { max_unavailable = 1 }

  labels = { role = "application", environment = var.environment }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_ecr,
    aws_iam_role_policy_attachment.nodes_cni,
  ]

  tags      = { Name = "${var.cluster_name}-nodes" }
  lifecycle { ignore_changes = [scaling_config[0].desired_size] }
}

# ── Core Addons ───────────────────────────────────────────────────────────────
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = var.vpc_cni_irsa_role_arn
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}
