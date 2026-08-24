# ========================================
# Variáveis para Data Lake (S3 Buckets)
# ========================================

variable "bucket_raw_haja_coracao" {
  type        = string
  description = "Nome base do bucket Raw - dados brutos de atletas"
  default     = "haja-coracao-raw"
}

variable "bucket_trusted_haja_coracao" {
  type        = string
  description = "Nome base do bucket Trusted - dados processados"
  default     = "haja-coracao-trusted"
}

variable "bucket_client_haja_coracao" {
  type        = string
  description = "Nome base do bucket Client - dados finalizados para consumo"
  default     = "haja-coracao-client"
}

# ========================================
# Variáveis para Instâncias EC2
# ========================================

variable "grafana_instance_type" {
  type        = string
  description = "Tipo de instância EC2 para Grafana"
  default     = "t3.medium"
}

variable "data_integration_instance_type" {
  type        = string
  description = "Tipo de instância EC2 para Data Integration"
  default     = "t3.small"
}

variable "kali_instance_type" {
  type        = string
  description = "Tipo de instância EC2 para testes de segurança (Kali)"
  default     = "t3.medium"
}

# ========================================
# Variáveis de Projeto
# ========================================

variable "project_name" {
  type        = string
  description = "Nome do projeto"
  default     = "haja-coracao"
}

variable "project_description" {
  type        = string
  description = "Descrição do projeto - Monitoramento de BPM de atletas de futebol"
  default     = "Sistema de monitoramento de batida cardíaca (BPM) de atletas de futebol em tempo real"
}

variable "aws_region" {
  type        = string
  description = "Região AWS para deploy"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Ambiente (development, staging, production)"
  default     = "development"
}

# ========================================
# Tags Comuns
# ========================================

variable "common_tags" {
  type = map(string)
  description = "Tags comuns para todos os recursos"
  default = {
    Project     = "Haja-Coracao"
    Purpose     = "BPM-Monitoring"
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

# ========================================
# API Gateway
# ========================================

variable "api_gateway_s3_integration_role_name" {
  type        = string
  description = "Nome da IAM Role para integração API Gateway → S3"
  default     = "LabRole"
}