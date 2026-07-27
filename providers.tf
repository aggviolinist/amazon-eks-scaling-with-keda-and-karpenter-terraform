provider "aws" {
    region = var.aws_region
}

provider "kubernetes" {
    host = aws_eks_cluster.clasta.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.clasta.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command = "aws"
      args = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
}

provider "helm" {
    kubernetes {
      host = aws_eks_cluster.clasta.endpoint
      cluster_ca_certificate = base64decode(aws_eks_cluster.clasta.certificate_authority[0].data)

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command = "aws"
        args = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
      }
    }
}

provider "kubectl" {
    host = aws_eks_cluster.clasta.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.clasta.certificate_authority[0].data)
    load_config_file = false

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command = "aws"
      args = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  
}

