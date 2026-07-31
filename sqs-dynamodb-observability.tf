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