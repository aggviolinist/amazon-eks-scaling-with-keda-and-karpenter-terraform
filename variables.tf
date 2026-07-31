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

variable "keda_version" {
  description = "KEDA Helm chart verison"
  type = string
  default = "2.19.0"
}

variable "keda_namespace" {
  type = string
  default = "keda"
}

variable "keda_operator_service_account" {
  type = string
  default = "keda-operator"
}

variable "keda_app_namespace" {
  description = "Namespace for the demo app KEDA scales"
  type = string
  default = "keda-test-app"
}

variable "keda_app_service_account" {
  type = string
  default = "keda-service-account"
}

variable "keda_target_deployment" {
  description = "Name of the k8s deplyoment KEDA scales"
  type = string
  default = "sqs-app"
}

variable "dynamodb_table_name" {
  type = string
  default = "payments"
}

variable "sqs_queue_name" {
  type = string
  default = "keda-demo-queue.fifo"
}