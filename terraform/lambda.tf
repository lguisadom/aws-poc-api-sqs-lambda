data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/src"
  output_path = "${path.module}/build/notifications-consumer.zip"
}

# Declared explicitly so the log group is managed by Terraform and gets a
# bounded retention. If we let Lambda auto-create it, retention defaults to
# "Never expire" and the group survives `terraform destroy`.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name_prefix}-notifications-consumer"
  retention_in_days = 7
}

resource "aws_lambda_function" "notifications_consumer" {
  function_name = "${local.name_prefix}-notifications-consumer"
  role          = aws_iam_role.lambda_exec.arn

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = "nodejs24.x"
  handler = "index.handler"
  timeout = 10

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_logs,
    aws_cloudwatch_log_group.lambda,
  ]
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn = aws_sqs_queue.notifications.arn
  function_name    = aws_lambda_function.notifications_consumer.arn

  # Small batch keeps per-invocation latency low for a notifications use case.
  # Increase for higher throughput / cost optimization.
  batch_size = 5
  enabled    = true
}
