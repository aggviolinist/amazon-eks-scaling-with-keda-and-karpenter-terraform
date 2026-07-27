output "cluster_name" {
  value = aws_eks_cluster.clasta.name
}
output "cluster_endpoint" {
  value = aws_eks_cluster.clasta.endpoint
}
output "cluster_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}
output "vpc_id" {
  value = aws_vpc.eks-vpc.id
}
output "private_ids" {
  value = aws_subnet.private[*].id
}
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}