terraform {
  required_version = ">=1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.32"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.15"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~>2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}