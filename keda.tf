resource "kubernetes_namespace" "keda" {
  metadata {
    name = var.keda_namespace
  }
}

resource "kubernetes_namespace" "keda_test_app" {
    metadata {
      name = var.keda_app_namespace
    }
}

resource "aws_iam_role" "keda" {
    name = "keda-demo-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Principal = {Federated = aws_iam_openid_connect_provider.eks.arn}
            Action = "sts:AssumeRoleWithWebIdentity"
            Condition = {
                StringEquals = {
                    "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "" )}:aud" = "sts.amazonaws.com"
                    "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = [
                        "system:serviceaccount:${var.keda_namespace}:${var.keda_operator_service_account}",
                        "system:serviceaccount:${var.keda_app_namespace}:${var.keda_app_service_account}",
                    ]
                }
            }
        }]
    })
}

resource "aws_iam_policy" "keda_sqs" {
    name = "keda-demo-sqs"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = "sqs:*"
            Resource = "*"
        }]
    })
}

resource "aws_iam_policy" "keda_dynamo" {
    name = "keda-demo-dynamo"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = "dynamodb:*"
            Resource = "*"
        }]
    }) 
}

resource "aws_iam_role_policy_attachment" "keda_sqs" {
    role = aws_iam_role.keda.name
    policy_arn = aws_iam_policy.keda_sqs.arn
}

resource "aws_iam_role_policy_attachment" "keda_dynamo" {
    role = aws_iam_role.keda.name
    policy_arn = aws_iam_policy.keda_dynamo.arn
}

resource "kubernetes_service_account" "keda_app" {
    metadata {
      name = var.keda_app_service_account
      namespace = kubernetes_namespace.keda_test_app.metadata[0].name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.keda.arn
      }
    } 
}

resource "helm_release" "keda" {
    name = var.keda_namespace
    repository = "https://kedacore.github.io/charts"
    chart = "keda"
    version = var.keda_version
    namespace = kubernetes_namespace.keda.metadata[0].name 

    set{
        name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = aws_iam_role.keda.arn
    }
    depends_on = [ 
        aws_eks_node_group.bootstrap,
        kubernetes_namespace.keda,
     ]
}
