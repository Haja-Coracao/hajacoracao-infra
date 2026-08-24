# Não esqueça do "terraform init"
# Não esqueçam de configurar as credenciais (aws configure e aws configure set aws_session_token)
# A Chave .pem para acesso é o labuser do console da AWS (AWS Details > Download PEM)

# Para iniciar: terraform apply -auto-approve
# Para apagar: terraform destroy -auto-approve

# Aguarde aproximadamente 7 minutos para tentar acessar a URL

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = "us-east-1"
}

# Gerar chave SSH automaticamente
resource "random_id" "key_id" {
  byte_length = 4
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "generated_key" {
  key_name   = "vockey-${random_id.key_id.hex}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Salvar a chave privada localmente
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "./${aws_key_pair.generated_key.key_name}.pem"
}

# Sufixos aleatórios para buckets
resource "random_string" "raw_suffix" {
  length  = 8
  special = false
  upper   = false
  keepers = {
    time = timestamp()
  }
}

resource "random_string" "trusted_suffix" {
  length  = 8
  special = false
  upper   = false
  keepers = {
    time = timestamp()
  }
}

resource "random_string" "client_suffix" {
  length  = 8
  special = false
  upper   = false
  keepers = {
    time = timestamp()
  }
}


########################################################
# Infraestrutura base da AWS
# - 1 EC2
# - Data Integration na EC2 (pendente) 
# - 3 Buckets S3 para Data Lake
########################################################

# Security Group da EC2 com Data Integration
resource "aws_security_group" "sg_data_integration" {
  name        = "sg_data_integration"
  description = "Acesso SSH e HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instância EC2 com Data Integration
resource "aws_instance" "ec2_data_integration" {
  ami                         = "ami-08c40ec9ead489470"
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.sg_data_integration.id]
  associate_public_ip_address = true
  iam_instance_profile = "LabInstanceProfile"

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
    delete_on_termination = true
  }

  provisioner "file" {
    source      = "./dados.py"
    destination = "/home/ubuntu/dados.py"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh_key.private_key_pem
    }
  }

  provisioner "file" {
    source      = "./Teste_PySpark/pyspark_test.ipynb"
    destination = "/home/ubuntu/pyspark_test.ipynb"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh_key.private_key_pem
    }
  }

  user_data = templatefile("./data_integration_setup.sh", {})

  tags = {
    Name = "data-integration-ec2"
  }
}

# DATA LAKE

# Bucket Raw
resource "aws_s3_bucket" "bucket-raw" {
  bucket = lower("${var.bucket_raw_haja_coracao}-${random_string.raw_suffix.result}")
  force_destroy  = true

  tags = {
    Name        = "Bucket_RAW_HAJA_CORACAO"
  }
}

# Upload de CSV para teste do PySpark
resource "aws_s3_object" "file_upload" {
  bucket = aws_s3_bucket.bucket-raw.id
  key    = "dados-teste.csv"
  source = "./dados-teste.csv"
}

# Bucket Trusted
resource "aws_s3_bucket" "bucket-trusted" {
  bucket = lower("${var.bucket_trusted_haja_coracao}-${random_string.trusted_suffix.result}")
  force_destroy  = true

  tags = {
    Name        = "Bucket_TRUSTED_HAJA_CORACAO"
  }
}

# Bucket Client
resource "aws_s3_bucket" "bucket-client" {
  bucket = lower("${var.bucket_client_haja_coracao}-${random_string.client_suffix.result}")
  force_destroy  = true

  tags = {
    Name        = "Bucket_CLIENT_HAJA_CORACAO"
  }
}

########################################################


########################################################
# Configuração do ambiente de teste de segurança (Kali)
########################################################

# Data source para obter região atual
data "aws_region" "current" {}

# Scripts da pipeline Kali compactados
data "archive_file" "kali_scripts" {
  type        = "zip"
  source_dir  = "./Scripts_Pipeline_Kali"
  output_path = "./Scripts_Pipeline_Kali.zip"
}

# Security Group instância Kali
resource "aws_security_group" "sg_kalilab" {
  name        = "sg_kalilab"
  description = "Acesso SSH e Kali"

  # Acesso SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta do conteiner de Kali
  ingress {
    from_port   = 6901
    to_port     = 6901
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta da API Flask para ingestão de dados (api_ingestao.py)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta de simulação de bucket S3 (LocalStack - testes locais)
  ingress {
    from_port   = 4566
    to_port     = 4566
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instância EC2 com Kali
resource "aws_instance" "ec2_kali" {
  ami                         = "ami-0b6c6ebed2801a5cb"
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.sg_kalilab.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
    delete_on_termination = true
  }

  user_data = templatefile("./kali_userdata.tpl", {
    scripts_zip_b64 = filebase64(data.archive_file.kali_scripts.output_path)
    kalilab_sh      = file("./kalilab.sh")
    bucket_raw_name = aws_s3_bucket.bucket-raw.id
  })

  user_data_replace_on_change = true

  tags = {
    Name = "ec2-Kali"
  }
}

# URL para acessar o Kali
output "url_kali" {
  description = "URL do Kali. Aguarde aprox. 7 minutos para acessar"
  value       = "https://${aws_instance.ec2_kali.public_ip}:6901"
}

########################################################
# Security Group e EC2 para Grafana
########################################################

resource "aws_security_group" "sg_grafana" {
  name        = "sg_grafana_haja_coracao"
  description = "Acesso SSH e Grafana"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS para conexão com S3 e Amazon Athena (conforme guia Metatron 3.0)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-grafana-haja-coracao"
  }
}

resource "aws_instance" "ec2_grafana" {
  ami                         = "ami-08c40ec9ead489470"
  instance_type               = var.grafana_instance_type
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.sg_grafana.id]
  associate_public_ip_address = true
  iam_instance_profile        = "LabInstanceProfile"

  root_block_device {
    volume_size           = 30
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = file("./grafana_setup.sh")

  tags = {
    Name = "ec2-grafana-haja-coracao"
  }
}

output "url_grafana" {
  description = "URL do Grafana. Aguarde aprox. 2-5 minutos para o serviço iniciar"
  value       = "http://${aws_instance.ec2_grafana.public_ip}:3000"
}

########################################################
# API Gateway para integração com S3 (Upload direto)
########################################################

# O API Gateway usa esta role na integração AWS → S3 (campo credentials).
data "aws_iam_role" "api_gateway_s3_integration" {
  name = var.api_gateway_s3_integration_role_name
}

# API Gateway REST
resource "aws_api_gateway_rest_api" "s3_upload_api" {
  name        = "s3-upload-api-haja-coracao"
  description = "API para upload direto no S3 (proxy AWS) - Haja Coração"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "s3-upload-api-haja-coracao"
  }
}

# Recurso /{bucket}
resource "aws_api_gateway_resource" "bucket_resource" {
  rest_api_id = aws_api_gateway_rest_api.s3_upload_api.id
  parent_id   = aws_api_gateway_rest_api.s3_upload_api.root_resource_id
  path_part   = "{bucket}"
}

# Método PUT — corpo = conteúdo do objeto; chave no S3 = requestId do API Gateway (único)
resource "aws_api_gateway_method" "put_method" {
  rest_api_id   = aws_api_gateway_rest_api.s3_upload_api.id
  resource_id   = aws_api_gateway_resource.bucket_resource.id
  http_method   = "PUT"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.bucket" = true
  }
}

resource "aws_api_gateway_integration" "put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.s3_upload_api.id
  resource_id             = aws_api_gateway_resource.bucket_resource.id
  http_method             = aws_api_gateway_method.put_method.http_method
  type                    = "AWS"
  integration_http_method = "PUT"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:s3:path/{bucket}/{object}"
  credentials             = data.aws_iam_role.api_gateway_s3_integration.arn
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.bucket"           = "method.request.path.bucket"
    "integration.request.path.object"           = "context.requestId"
    "integration.request.header.Content-Type"   = "'application/json'"
  }
}

resource "aws_api_gateway_method_response" "put_response_200" {
  rest_api_id = aws_api_gateway_rest_api.s3_upload_api.id
  resource_id = aws_api_gateway_resource.bucket_resource.id
  http_method = aws_api_gateway_method.put_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "put_integration_response_200" {
  rest_api_id       = aws_api_gateway_rest_api.s3_upload_api.id
  resource_id       = aws_api_gateway_resource.bucket_resource.id
  http_method       = aws_api_gateway_method.put_method.http_method
  status_code       = "200"
  selection_pattern = ""

  depends_on = [aws_api_gateway_integration.put_integration]
}

# Stage de homologação (hmg)
resource "aws_api_gateway_stage" "hmg_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.s3_upload_api.id
  stage_name    = "hmg"

  tags = {
    Name = "hmg-stage"
  }
}

# Deployment da API
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.s3_upload_api.id

  depends_on = [
    aws_api_gateway_integration_response.put_integration_response_200,
    aws_api_gateway_method.put_method
  ]
}

# Output - URL do API Gateway
output "api_gateway_url" {
  description = "URL base do API Gateway para upload de arquivos no S3 (Haja Coração)"
  value       = "https://${aws_api_gateway_rest_api.s3_upload_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.hmg_stage.stage_name}"
}

########################################################
# Referência ao IAM Role do Lab
########################################################

# Já existe acima - comentar a declaração duplicada se houver

data "aws_iam_role" "lab_role_from_profile" {
  name = "LabRole"
}

########################################################
# Configuração da Função Lambda - Raw para Trusted
########################################################

# Arquivo com código para função lambda
data "archive_file" "lambda_raw_zip" {
  type        = "zip"
  source_file = "./lambda_raw.py"
  output_path = "lambda_raw.zip"
}

# Função Lambda
resource "aws_lambda_function" "lambda_function_raw" {
  function_name = "lambda-raw-to-trusted-haja-coracao"
  handler       = "lambda_raw.handler"
  runtime       = "python3.12"
  role          = data.aws_iam_role.lab_role_from_profile.arn
  filename      = data.archive_file.lambda_raw_zip.output_path
  environment {
    variables = {
      DEST_BUCKET = aws_s3_bucket.bucket-trusted.id
    }
  }

  source_code_hash = data.archive_file.lambda_raw_zip.output_base64sha256

  tags = {
    Name = "lambda-raw-to-trusted-haja-coracao"
  }
}

# Permissão para o S3 invocar a Lambda
resource "aws_lambda_permission" "allow_s3_invoke_raw" {
  statement_id  = "AllowExecutionFromS3Raw"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function_raw.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket-raw.arn
}

# NOTIFICAÇÃO DO BUCKET (gatilho)
resource "aws_s3_bucket_notification" "bucket_notification_raw" {
  bucket = aws_s3_bucket.bucket-raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_function_raw.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke_raw, aws_s3_bucket.bucket-raw]
}

########################################################
# Configuração da Função Lambda - Trusted para Client
########################################################

# Arquivo com código para função lambda
data "archive_file" "lambda_trusted_zip" {
  type        = "zip"
  source_file = "./lambda_trusted.py"
  output_path = "lambda_trusted.zip"
}

# Função Lambda
resource "aws_lambda_function" "lambda_function_trusted" {
  function_name = "lambda-trusted-to-client-haja-coracao"
  handler       = "lambda_trusted.handler"
  runtime       = "python3.12"
  role          = data.aws_iam_role.lab_role_from_profile.arn
  filename      = data.archive_file.lambda_trusted_zip.output_path
  environment {
    variables = {
      DEST_BUCKET = aws_s3_bucket.bucket-client.id
    }
  }

  source_code_hash = data.archive_file.lambda_trusted_zip.output_base64sha256

  tags = {
    Name = "lambda-trusted-to-client-haja-coracao"
  }
}

# Permissão para o S3 invocar a Lambda
resource "aws_lambda_permission" "allow_s3_invoke_trusted" {
  statement_id  = "AllowExecutionFromS3Trusted"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function_trusted.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket-trusted.arn
}

# NOTIFICAÇÃO DO BUCKET (gatilho)
resource "aws_s3_bucket_notification" "bucket_notification_trusted" {
  bucket = aws_s3_bucket.bucket-trusted.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_function_trusted.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke_trusted, aws_s3_bucket.bucket-trusted]
}

########################################################
# Outputs Gerais
########################################################

# IMPORTANTE: Configuração do Amazon Athena (Guia Metatron 3.0)
# 1. Acesse o console AWS Athena
# 2. Configure o Data Source com:
#    - Authentication: Access Key & Secret Key (AWS Educate)
#    - Region: us-east-1
#    - Output Location: s3://seu-bucket/results/
# 3. Use o plugin "Amazon Athena" (não BigQuery ou SQL Server)
# 4. Query exemplo: SELECT temp FROM telemetry ORDER BY ts DESC LIMIT 1

output "url_jupyter" {
  description = "URL do Jupyter. Aguarde aprox. 5 minutos para acessar"
  value       = "http://${aws_instance.ec2_data_integration.public_ip}:80"
}

output "bucket_raw_name" {
  description = "Nome do Bucket Raw (dados brutos)"
  value       = aws_s3_bucket.bucket-raw.id
}

output "bucket_trusted_name" {
  description = "Nome do Bucket Trusted (dados processados)"
  value       = aws_s3_bucket.bucket-trusted.id
}

output "bucket_client_name" {
  description = "Nome do Bucket Client (dados finalizados)"
  value       = aws_s3_bucket.bucket-client.id
}

output "lambda_raw_function_name" {
  description = "Nome da função Lambda Raw → Trusted"
  value       = aws_lambda_function.lambda_function_raw.function_name
}

output "lambda_trusted_function_name" {
  description = "Nome da função Lambda Trusted → Client"
  value       = aws_lambda_function.lambda_function_trusted.function_name
}

output "ec2_data_integration_ip" {
  description = "IP público da EC2 Data Integration"
  value       = aws_instance.ec2_data_integration.public_ip
}

output "ec2_grafana_ip" {
  description = "IP público da EC2 Grafana"
  value       = aws_instance.ec2_grafana.public_ip
}

output "ec2_kali_ip" {
  description = "IP público da EC2 Kali"
  value       = aws_instance.ec2_kali.public_ip
}