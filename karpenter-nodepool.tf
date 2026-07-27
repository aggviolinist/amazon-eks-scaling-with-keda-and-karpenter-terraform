resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
      apiVersion: karpenter.sh/v1
      kind: NodePool
      metadata:
        name: default
      spec:
        template:
          spec: 
            expireAfter: 720h
            requirements: 
              - key: karpenter.sh/capacity-type
                operator: NotIn
                values: ["spot"]
              - key: node.kubernetes.io/instance-type
                operator: In
                values: ${jsonencode(var.karpenter_node_instance_type)}
            nodeClassRef:
               group: karpenter.k8s.aws
               kind: EC2NodeClass
               name: default
        limits:
          cpu: 1000
        disruption:
          consolidationPolicy: WhenEmptyOrUnderutilized
          consolidateAfter: 30s
    YAML

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "karpenter_ec2_node_class" {
  yaml_body = <<-YAML
      apiVersion: karpenter.k8s.aws/v1
      kind: EC2NodeClass
      metadata: 
        name: default
      spec: 
        amiSelectorTerms:
          - alias: al2023@latest
        role: "${aws_iam_role.karpenter_node.name}"
        subnetSelectorTerms:
            - tags: 
                karpenter.sh/discovery: "${var.cluster_name}"
        securityGroupSelectorTerms:
            - tags:
                karpenter.sh/discovery: "${var.cluster_name}" 
    YAML

  depends_on = [helm_release.karpenter]
}