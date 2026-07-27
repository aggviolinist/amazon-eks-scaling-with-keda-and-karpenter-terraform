locals {
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

# KarpenterNodeRole: The role EC2 instances Karpenter launches will assume
resource "aws_iam_role" "karpenter_node" {
  name = "KarpenterNodeRole-${var.cluster_name}"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}
resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Register the node role so EC2 instances launched with it can join the cluster
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = aws_eks_cluster.clasta.name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}

# 6 Official Karpenter Policies
resource "aws_iam_policy" "karpenter_node_lifecycle" {
  name = "KarpenterControllerNodeLifecyclePolicy-${var.cluster_name}"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceAccessActions"
        Effect = "Allow"
        Resource = [
          "arn:${local.partition}:ec2:${local.region}::image/*",
          "arn:${local.partition}:ec2:${local.region}::snapshot/*",
          "arn:${local.partition}:ec2:${local.region}:*:security-group/*",
          "arn:${local.partition}:ec2:${local.region}:*:subnet/*",
          "arn:${local.partition}:ec2:${local.region}:*:capacity-reservation/*",
          "arn:${local.partition}:ec2:${local.region}:*:placement-group/*",
        ]
        Action = ["ec2:RunInstances", "ec2:CreateFleet"]
      },
      {
        Sid      = "AllowScopedEC2LaunchTemplateAccessActions"
        Effect   = "Allow"
        Resource = "arn:${local.partition}:ec2:${local.region}:*:launch-template/*"
        Action   = ["ec2:RunInstances", "ec2:CreateFleet"]
        Condition = {
          StringEquals = { "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned" }
          StringLike   = { "aws:ResourceTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid    = "AllowScopedEC2InstanceActionsWithTags"
        Effect = "Allow"
        Resource = [
          "arn:${local.partition}:ec2:${local.region}:*:fleet/*",
          "arn:${local.partition}:ec2:${local.region}:*:instance/*",
          "arn:${local.partition}:ec2:${local.region}:*:volume/*",
          "arn:${local.partition}:ec2:${local.region}:*:network-interface/*",
          "arn:${local.partition}:ec2:${local.region}:*:launch-template/*",
          "arn:${local.partition}:ec2:${local.region}:*:spot-instances-request/*",
        ]
        Action = ["ec2:RunInstances", "ec2:CreateFleet", "ec2:CreateLaunchTemplate"]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                      = var.cluster_name
          }
          StringLike = { "aws:RequestTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid    = "AllowScopedResourceCreationTagging"
        Effect = "Allow"
        Resource = [
          "arn:${local.partition}:ec2:${local.region}:*:fleet/*",
          "arn:${local.partition}:ec2:${local.region}:*:instance/*",
          "arn:${local.partition}:ec2:${local.region}:*:volume/*",
          "arn:${local.partition}:ec2:${local.region}:*:network-interface/*",
          "arn:${local.partition}:ec2:${local.region}:*:launch-template/*",
          "arn:${local.partition}:ec2:${local.region}:*:spot-instances-request/*",
        ]
        Action = "ec2:CreateTags"
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                      = var.cluster_name
            "ec2:CreateAction"                                         = ["RunInstances", "CreateFleet", "CreateLaunchTemplate"]
          }
          StringLike = { "aws:RequestTag/karpenter.sh/nodepool" = "*" }
        }
      },
      {
        Sid      = "AllowScopedResourceTagging"
        Effect   = "Allow"
        Resource = "arn:${local.partition}:ec2:${local.region}:*:instance/*"
        Action   = "ec2:CreateTags"
        Condition = {
          StringEquals         = { "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned" }
          StringLike           = { "aws:ResourceTag/karpenter.sh/nodepool" = "*" }
          StringEqualsIfExists = { "aws:RequestTag/eks:eks-cluster-name" = var.cluster_name }
          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = ["eks:eks-cluster-name", "karpenter.sh/nodeclaim", "Name"]
          }
        }
      },
      {
        Sid    = "AllowScopedDeletion"
        Effect = "Allow"
        Resource = [
          "arn:${local.partition}:ec2:${local.region}:*:instance/*",
          "arn:${local.partition}:ec2:${local.region}:*:launch-template/*",
        ]
        Action = ["ec2:TerminateInstances", "ec2:DeleteLaunchTemplate"]
        Condition = {
          StringEquals = { "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned" }
          StringLike   = { "aws:ResourceTag/karpenter.sh/nodepool" = "*" }
        }
      },

    ]
  })
}

resource "aws_iam_policy" "karpenter_iam_integration" {
  name = "KarpenterControllerIAMIntegrationPolicy-${var.cluster_name}"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowPassingInstanceRole"
        Effect   = "Allow"
        Resource = aws_iam_role.karpenter_node.arn
        Action   = "iam:PassRole"
        Condition = {
          StringEquals = { "iam:PassedToService" = ["ec2.amazonaws.com", "ec2.amazonaws.com.cn"] }
        }
      },
      {
        Sid      = "AllowScopedInstanceProfileCreationActions"
        Effect   = "Allow"
        Resource = "arn:${local.partition}:iam::${local.account_id}:instance-profile/*"
        Action   = ["iam:CreateInstanceProfile"]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                      = var.cluster_name
            "aws:RequestTag/topology.kubernetes.io/region"             = local.region
          }
          StringLike = { "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*" }
        }
      },
      {
        Sid      = "AllowScopedInstanceProfileTagActions"
        Effect   = "Allow"
        Resource = "arn:${local.partition}:iam::${local.account_id}:instance-profile/*"
        Action   = ["iam:TagInstanceProfile"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"             = local.region
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"  = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                       = var.cluster_name
            "aws:RequestTag/topology.kubernetes.io/region"              = local.region
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"  = "*"

          }
        }
      },
      {
        Sid      = "AllowScopedInstanceProfileActions"
        Effect   = "Allow"
        Resource = "arn:${local.partition}:iam::${local.account_id}:instance-profile/*"
        Action   = ["iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:DeleteInstanceProfile"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"             = local.region
          }
          StringLike = { "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*" }
        }
      },
    ]
  })
}

resource "aws_iam_policy" "karpenter_eks_integration" {
  name = "KarpenterControllerEKSIntegrationPolicy-${var.cluster_name}"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowAPIServerEndpointDiscovery"
      Effect   = "Allow"
      Resource = "arn:${local.partition}:eks:${local.region}:${local.account_id}:cluster/${var.cluster_name}"
      Action   = "eks:DescribeCluster"
    }]
  })
}

resource "aws_iam_policy" "karpenter_interruption" {
  name = "KarpenterControllerInterruptionPolicy-${var.cluster_name}"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowInterruptionQueueActions"
      Effect   = "Allow"
      Resource = aws_sqs_queue.karpenter_interruption.arn
      Action   = ["sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]
    }]
  })
}

resource "aws_iam_policy" "karpenter_zonal_shift" {
  name = "KarpenterControllerZonalShiftPolicy-${var.cluster_name}"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowZonalShiftStatusReadOnly"
      Effect   = "Allow"
      Resource = "*"
      Action   = ["arc-zonal-shift:GetManagedResource"]
      Condition = {
        StringEquals = {
          "arc-zonal-shift:ResourceIdentifier" = "arn:${local.partition}:eks:${local.region}:${local.account_id}:cluster/${var.cluster_name}"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "karpenter_resource_discovery" {
  name = "KarpenterControllerResourceDiscoveryPolicy-${var.cluster_name}"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowRegionalReadActions"
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "ec2:DescribeCapacityReservations",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribePlacementGroups",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
        ]
        Condition = { StringEquals = { "aws:RequestedRegion" = local.region } }
      },
      {
        Sid      = "AllowSSMReadActions"
        Effect   = "Allow"
        Resource = "arn:${local.partition}:ssm:${local.region}::parameter/aws/service/*"
        Action   = "ssm:GetParameter"
      },
      {
        Sid      = "AllowPricingReadActions"
        Effect   = "Allow"
        Resource = "*"
        Action   = "pricing:GetProducts"
      },
      {
        Sid      = "AllowUnscopedInstanceProfileListAction"
        Effect   = "Allow"
        Resource = "*"
        Action   = "iam:ListInstanceProfiles"
      },
      {
        Sid      = "AllowInstanceProfileReadActions"
        Effect   = "Allow"
        Resource = "arn:${local.partition}:iam::${local.account_id}:instance-profile/*"
        Action   = "iam:GetInstanceProfile"
      },
    ]
  })
}

# ---SQS interruption queue + policy (spot/health/rebalance events land here) ----
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = var.cluster_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Id      = "EC2InterruptionPolicy"
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "sqs:*"
        Resource  = aws_sqs_queue.karpenter_interruption.arn
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })
}

# --EventBridge rules that feed the interruption queue ---
locals {
  karpenter_interruption_rules = {
    scheduled_change      = { source = "aws.health", detail_type = "AWS Health Event" }
    spot_interruption     = { source = "aws.ec2", detail_type = "EC2 Spot Instance Interruption Warning" }
    rebalance             = { source = "aws.ec2", detail_type = "EC2 Instance Rebalance Recommendation" }
    instance_state_change = { source = "aws.ec2", detail_type = "EC2 Instance State-change Notification" }
    capacity_reservation  = { source = "aws.ec2", detail_type = "EC2 Capacity Reservation Instance Interruption Warning" }
  }
}

resource "aws_cloudwatch_event_rule" "karpenter_interruption" {
  for_each = local.karpenter_interruption_rules

  name = "Karpenter-${var.cluster_name}-${each.key}"
  event_pattern = jsonencode({
    source      = [each.value.source]
    detail-type = [each.value.detail_type]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_interruption" {
  for_each = local.karpenter_interruption_rules

  rule = aws_cloudwatch_event_rule.karpenter_interruption[each.key].name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# ---Karpenter controller's own IRSA role (assumed via its k8s SA)
resource "aws_iam_role" "karpenter_controller" {
  name = "Karpenter-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  for_each = {
    node_lifecyle      = aws_iam_policy.karpenter_node_lifecycle.arn
    iam_integraton     = aws_iam_policy.karpenter_iam_integration.arn
    eks_integration    = aws_iam_policy.karpenter_eks_integration.arn
    interruption       = aws_iam_policy.karpenter_interruption.arn
    zonal_shift        = aws_iam_policy.karpenter_zonal_shift.arn
    resource_discovery = aws_iam_policy.karpenter_resource_discovery.arn
  }
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = each.value
}

# ---ec2 Spot service-linked role
### When Karpenter's controller calls 
### ec2:RunInstances or ec2:CreateFleet with spot as the
### capacity type, AWS's Spot fleet management machinery 
### kicks in — and that machinery relies on this service-linked role existing.
# resource "aws_iam_service_linked_role" "spot" {
#   aws_service_name = "spot.amazonaws.com"
# }

## Helm: CRDs first then controller
resource "helm_release" "karpenter_crd" {
  name             = "karpenter-crd"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = var.karpenter_version
  namespace        = "karpenter"
  create_namespace = true
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version
  namespace  = "karpenter"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }
  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.karpenter_interruption.name
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }
  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  depends_on = [
    helm_release.karpenter_crd,
    aws_eks_node_group.bootstrap,
    aws_eks_access_entry.karpenter_node,
  ]
}

### Before you apply, check the ec2 Spot service-linked role
### using
### aws iam get-role --role-name AWSServiceRoleForEC2Spot. 
### If it returns a role, delete the 
### aws_iam_service_linked_role.spot