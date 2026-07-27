variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-demo-scale"
}
variable "kubernetes_version" {
  description = "EKS control plane version"
  type        = string
  default     = "1.36"
}
variable "vpc_cidr" {
  description = "CIDR block for the cluster VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "az_count" {
  description = "AZs spread subnets across"
  type        = number
  default     = 2
}
variable "node_instance_type" {
  description = "Instance type for the bootstrap managed node group"
  type        = string
  default     = "t3.medium"
}
variable "node_group_desired_size" {
  type    = number
  default = 2
}
variable "node_group_min_size" {
  type    = number
  default = 1
}
variable "node_group_max_size" {
  type    = number
  default = 4
}
variable "karpenter_version" {
  description = "Karpenter Helm chart/ controller version"
  type        = string
  default     = "1.14.0"
}
variable "karpenter_node_instance_type" {
  description = "Instance types Karpenter is allowed to launch"
  type        = list(string)
  default     = ["t2.medium", "t3.medium"]
}