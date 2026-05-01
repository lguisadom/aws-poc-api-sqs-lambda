# Two distinct roles by design (least privilege):
#   - lambda_exec:   only Receive/Delete from the queue + write logs
#   - apigw_to_sqs:  only SendMessage to the queue
# Splitting them prevents either side from doing the other's job if compromised.

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_sqs_consume" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.notifications.arn]
  }
}

resource "aws_iam_role_policy" "lambda_sqs_consume" {
  name   = "${local.name_prefix}-lambda-sqs-consume"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_sqs_consume.json
}

data "aws_iam_policy_document" "apigw_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigw_to_sqs" {
  name               = "${local.name_prefix}-apigw-to-sqs"
  assume_role_policy = data.aws_iam_policy_document.apigw_assume_role.json
}

data "aws_iam_policy_document" "apigw_sqs_send" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.notifications.arn]
  }
}

resource "aws_iam_role_policy" "apigw_sqs_send" {
  name   = "${local.name_prefix}-apigw-sqs-send"
  role   = aws_iam_role.apigw_to_sqs.id
  policy = data.aws_iam_policy_document.apigw_sqs_send.json
}
