resource "aws_dynamodb_table" "demo_scaling_app" {
    name = var.dynamodb_table_name
    billing_mode = "PROVISIONED"
    read_capacity = 1
    write_capacity = 1
    hash_key = "id"
    range_key = "messageProcessingTime"

    attribute {
      name = "id"
      type = "S"
    }
    attribute {
      name = "messageProcessingTime"
      type = "S"
    }
}

resource "aws_sqs_queue" "demo_scaling_app" {
    name = var.sqs_queue_name
    fifo_queue = true
    content_based_deduplication = true
    visibility_timeout_seconds = 3600
    message_retention_seconds = 345600
}

resource "kubernetes_deployment" "sqs_app" {
  metadata {
    name = var.keda_target_deployment
    namespace = kubernetes_namespace.keda_test_app.metadata[0].name
  }
  spec {
    replicas = 1

    selector {
      match_labels = {app="sqs-reader"}
    }
    template {
      metadata {
        labels = {app = "sqs-reader"}
      }
      spec {
        service_account_name = kubernetes_service_account.keda_app.metadata[0].name

        container {
          name = "sqs-pull-app"
          image = "khanasif1/sqs-reader:v0.12"
          image_pull_policy = "Always"

          env {
            name = "SQS_QUEUE_URL"
            value = aws_sqs_queue.demo_scaling_app.url
          }
          env {
            name = "DYNAMO_TABLE"
            value= aws_dynamodb_table.demo_scaling_app.name
          }
          env {
            name = "AWS_REGION"
            value = var.aws_region
          }
          resources {
            requests = {
              memory = "512Mi"
              cpu = "500m"
            }
            limits = {
              memory = "512Mi"
              cpu = "500m"
            }
          }
        }
      }
    }
  }
  
depends_on = [ kubernetes_service_account.keda_app ]
}