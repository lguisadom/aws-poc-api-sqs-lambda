output "api_invoke_url" {
  description = "Full URL to POST notifications"
  value       = "${aws_api_gateway_stage.this.invoke_url}/notifications"
}

output "sqs_queue_url" {
  description = "URL of the notifications SQS queue"
  value       = aws_sqs_queue.notifications.url
}

output "sqs_queue_name" {
  description = "Name of the notifications SQS queue"
  value       = aws_sqs_queue.notifications.name
}

output "lambda_function_name" {
  description = "Name of the Lambda consumer function"
  value       = aws_lambda_function.notifications_consumer.function_name
}

output "lambda_log_group" {
  description = "CloudWatch log group for the Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}
