# aws-poc-api-sqs-lambda

POC de arquitectura serverless **fire-and-forget** en AWS: API Gateway recibe peticiones, las encola en SQS y una Lambda las procesa de forma asíncrona.

## Caso de negocio

Sistema de ingesta de **notificaciones** (email / SMS / push). El cliente del API no espera a que la notificación se envíe — solo recibe confirmación de que la solicitud quedó encolada.

Por qué encaja este patrón:

- Evita bloquear al cliente esperando un proveedor externo (SES, SNS, FCM, Twilio, etc.).
- Absorbe picos de tráfico en la cola.
- Desacopla el endpoint público del proceso de envío.

## Arquitectura

```
Cliente ──POST──▶ API Gateway ──▶ SQS ──▶ Lambda (Node.js 24)
                  (REST API)    (queue)   (consumer)
```

- **API Gateway** REST con integración nativa AWS service hacia SQS (sin Lambda intermedia en el path de ingesta).
- **SQS Standard Queue** como buffer.
- **Lambda** suscrita vía event source mapping; procesa batch y simula el envío con logs.

## Recursos

Los nombres usan el prefijo `${project_name}-${environment}` (defaults: `notifications-poc-dev`). Si cambias esas variables, los nombres cambian en consecuencia.

| Tipo Terraform | Nombre AWS | Propósito |
|---|---|---|
| `aws_api_gateway_rest_api` | `notifications-poc-dev-api` | API REST público |
| `aws_api_gateway_resource` | path `/notifications` | Recurso del API |
| `aws_api_gateway_method` | `POST /notifications` | Método HTTP |
| `aws_api_gateway_stage` | `v1` | Stage de despliegue |
| `aws_sqs_queue` | `notifications-poc-dev-notifications` | Cola de ingesta |
| `aws_lambda_function` | `notifications-poc-dev-notifications-consumer` | Lambda consumidor (`nodejs24.x`) |
| `aws_lambda_event_source_mapping` | (sin nombre) | Conecta SQS → Lambda |
| `aws_iam_role` | `notifications-poc-dev-lambda-exec` | Rol de ejecución de la Lambda |
| `aws_iam_role` | `notifications-poc-dev-apigw-to-sqs` | Rol que asume API Gateway para `SendMessage` |
| `aws_iam_role_policy` | `notifications-poc-dev-lambda-sqs-consume` | Permite a la Lambda leer/borrar de la cola |
| `aws_iam_role_policy` | `notifications-poc-dev-apigw-sqs-send` | Permite a API Gateway publicar en la cola |
| `aws_iam_role_policy_attachment` | `AWSLambdaBasicExecutionRole` (AWS managed) | Logs de CloudWatch para la Lambda |
| `aws_cloudwatch_log_group` | `/aws/lambda/notifications-poc-dev-notifications-consumer` | Logs de la Lambda (retención 7 días) |

## Requisitos

- Terraform `>= 1.6`
- AWS CLI con credenciales configuradas (`aws configure`)
- Permisos para crear API Gateway, SQS, Lambda, IAM y CloudWatch Logs

> El estado de Terraform se guarda **localmente** en `terraform/terraform.tfstate`.

## Despliegue

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

> Si modificas las versiones en `versions.tf`, usa `terraform init -upgrade` (y borra `.terraform.lock.hcl` si quieres un pin completamente nuevo). Un `init` simple respeta el lock previo y falla si el constraint cambió.

## Probar el flujo

```bash
# 1. Disparar petición
curl -X POST "$(terraform output -raw api_invoke_url)" \
  -H "Content-Type: application/json" \
  -d '{"userId":"u-123","channel":"email","template":"welcome","data":{"name":"Luis"}}'

# Respuesta esperada: HTTP 202 → {"messageId":"<uuid>"}

# 2. Ver el procesamiento en CloudWatch
aws logs tail "$(terraform output -raw lambda_log_group)" --follow
```

### Payload del API

```json
{
  "userId": "u-123",
  "channel": "email | sms | push",
  "template": "welcome",
  "data": { "name": "Luis" }
}
```

## Limpieza

```bash
terraform destroy
```

## Notas

- Solo **happy path**: sin DLQ, sin reintentos custom, sin validación de schema en el API.
- El `messageId` que devuelve el API confirma **aceptación en SQS**, no procesamiento de la notificación.
- El runtime `nodejs24.x` requiere que la cuenta AWS esté en una región que ya lo soporte.
