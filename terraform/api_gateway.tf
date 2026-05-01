resource "aws_api_gateway_rest_api" "this" {
  name        = "${local.name_prefix}-api"
  description = "Notifications ingestion API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "notifications" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "notifications"
}

resource "aws_api_gateway_method" "post_notifications" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.notifications.id
  http_method   = "POST"
  authorization = "NONE"
}

# Direct AWS service integration: API Gateway calls SQS without a Lambda proxy.
# SQS expects form-urlencoded with Action=SendMessage&MessageBody=...; the
# request template rewrites the incoming JSON into that format. The URL-encoded
# body becomes the message body the Lambda will read.
resource "aws_api_gateway_integration" "sqs" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.notifications.id
  http_method             = aws_api_gateway_method.post_notifications.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${local.region}:sqs:path/${local.account_id}/${aws_sqs_queue.notifications.name}"
  credentials             = aws_iam_role.apigw_to_sqs.arn

  passthrough_behavior = "NEVER"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
}

resource "aws_api_gateway_method_response" "accepted" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.notifications.id
  http_method = aws_api_gateway_method.post_notifications.http_method
  status_code = "202"

  response_models = {
    "application/json" = "Empty"
  }
}

# SQS replies with XML (SendMessageResponse → SendMessageResult → MessageId).
# This template extracts the MessageId and returns it as JSON so callers don't
# see SQS internals.
resource "aws_api_gateway_integration_response" "accepted" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.notifications.id
  http_method = aws_api_gateway_method.post_notifications.http_method
  status_code = aws_api_gateway_method_response.accepted.status_code

  response_templates = {
    "application/json" = <<EOT
#set($messageId = $input.path('$.SendMessageResponse.SendMessageResult.MessageId'))
{"messageId":"$messageId"}
EOT
  }

  depends_on = [aws_api_gateway_integration.sqs]
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.notifications.id,
      aws_api_gateway_method.post_notifications.id,
      aws_api_gateway_integration.sqs.id,
      aws_api_gateway_integration_response.accepted.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.sqs,
    aws_api_gateway_integration_response.accepted,
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.api_stage_name
}
