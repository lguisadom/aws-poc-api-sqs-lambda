resource "aws_sqs_queue" "notifications" {
  name = "${local.name_prefix}-notifications"

  # Must be >= lambda timeout (10s). 30s leaves headroom so a slow batch
  # is not redelivered while still being processed.
  visibility_timeout_seconds = 30

  # 4 days retention. Standard SQS default, enough for an outage window.
  message_retention_seconds = 345600

  # Long polling: reduces empty receives and SQS API cost.
  receive_wait_time_seconds = 10
}
