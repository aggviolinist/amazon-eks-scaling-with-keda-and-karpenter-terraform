amazon-eks-scaling-with-keda-and-karpenter-terraform/
├── README.md                 # phased how-to + teaching notes, mirrors original README structure
├── versions.tf               # terraform{} + required_providers: aws, kubernetes, helm, kubectl (alekc/kubectl), tls
├── providers.tf              # provider "aws" {}, kubernetes/helm/kubectl providers using exec-plugin auth via `aws eks get-token`
├── variables.tf              # direct port of deployment/environmentVariables.sh (region, cluster_name, k8s_version, karpenter_version, keda vars, sqs/dynamo names, etc.)
├── terraform.tfvars.example
├── data.tf                   # aws_caller_identity, aws_availability_zones, aws_eks_cluster/aws_eks_cluster_auth (for providers)
├── outputs.tf
│
│  ── Phase 1: cluster ──
├── vpc.tf                    # VPC, 2 public + 2 private subnets across 2 AZs, IGW, NAT GW(s)+EIP, route tables
│                             #   tags: kubernetes.io/cluster/<name>=shared, role/elb, role/internal-elb,
│                             #   private subnets + cluster SG also get karpenter.sh/discovery=<cluster_name>
├── eks-cluster.tf            # cluster IAM role, aws_eks_cluster (access_config.authentication_mode = API),
│                             #   aws_iam_openid_connect_provider (OIDC/IRSA), node IAM role, aws_eks_node_group
│                             #   (small on-demand bootstrap group — Karpenter takes over day-to-day scaling),
│                             #   aws_eks_access_entry for the caller identity (cluster-admin)
│
│  ── Phase 2: Karpenter ──
├── karpenter.tf              # KarpenterNodeRole+instance profile, aws_eks_access_entry (type EC2_LINUX) for it,
│                             #   controller IRSA role + 6 policies (ec2/iam/eks/sqs perms), SQS interruption
│                             #   queue + queue policy, 4 aws_cloudwatch_event_rule/target (health/spot/rebalance/
│                             #   state-change), helm_release "karpenter_crd", helm_release "karpenter"
├── karpenter-nodepool.tf     # kubectl_manifest for NodePool + EC2NodeClass (t2.medium/t3.medium, on-demand),
│                             #   depends_on the karpenter helm_release
│
│  ── Phase 3: KEDA + demo app ──
├── keda.tf                   # kubernetes_namespace "keda"/"keda-test", shared IAM role (trust: both operator
│                             #   + app SAs) + sqs/dynamo policies, kubernetes_service_account for the app SA
│                             #   with IRSA annotation, helm_release "keda" (kedacore/keda, operator SA
│                             #   annotation set via `set{}` blocks)
├── keda-scaledobject.tf      # kubectl_manifest: ScaledObject + TriggerAuthentication, depends_on helm_release.keda
├── demo-app.tf                # aws_dynamodb_table "payments", aws_sqs_queue (fifo), kubernetes_deployment "sqs-app"