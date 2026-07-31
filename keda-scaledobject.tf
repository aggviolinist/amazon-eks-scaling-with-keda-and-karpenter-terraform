resource "kubectl_manifest" "keda_trigger_authentication" {
    yaml_body = <<-YAML
      apiVersion: keda.sh/v1alpha1
      Kind: TriggerAuthentication
      metadata: 
        name: keda-aws-creds
        namespace: ${var.keda_app_namespace}
      spec:
        podIdentity:
          provider: aws-eks
    YAML

    depends_on = [helm_release.keda]
}

resource "kubectl_manifest" "keda_scaled_object" {
    yaml_body = <<-YAML
       apiVersion: keda.sh/alpha1
       Kind: ScaledObject
       metadata:
         name: aws-sqs-queue-scaledobject
         namespace: ${var.keda_app_namespace}
       spec:
         scaledTargetRef: 
           name: ${var.keda_target_deployment}
         minReplicaCount: 1
         maxReplicaCount: 15
         pollingInterval: 15
         cooldownPeriod: 5
         triggers:
           - type: aws-sqs-queue
             authenticationRef:
               name: keda-aws-creds
             metadata:
               queueURL: ${aws_sqs_queue.demo.url}
               queueLength: "1"
               awsRegion: ${var.aws_region}
               identityOwner: operator
    YAML

    depends_on = [ 
        helm_release.keda,
        kubectl_manifest.keda_trigger_authentication,
     ]
}