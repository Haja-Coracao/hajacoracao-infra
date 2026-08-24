terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "azurerm" {
  # Desabilita o registro automático de Resource Providers.
  # Em subscriptions de estudante o Terraform não tem permissão para registrar
  # todos os providers da Azure, gerando timeout. Registramos manualmente abaixo.
  skip_provider_registration = true

  features {}
}

# =============================================================================
# Variáveis
# =============================================================================

variable "location" {
  description = "Região Azure para deploy de todos os recursos"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Prefixo usado para nomear os recursos"
  type        = string
  default     = "iotlab"
}

variable "iot_hub_sku" {
  description = "SKU do IoT Hub. Atenção: apenas 1 hub F1 (free) por subscription. Se já existir um, altere para 'S1'."
  type        = string
  default     = "F1"

  validation {
    condition     = contains(["F1", "S1", "S2", "S3"], var.iot_hub_sku)
    error_message = "SKU deve ser F1, S1, S2 ou S3."
  }
}

variable "devices" {
  description = "Lista de IDs dos dispositivos IoT a serem registrados"
  type        = list(string)
  default     = ["device-01", "device-02", "device-03"]
}

# =============================================================================
# Dados
# =============================================================================

data "azurerm_client_config" "current" {}

# Sufixo único para recursos globalmente únicos (ex: storage account)
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  resource_group_name      = "rg-${var.prefix}"
  vnet_name                = "vnet-${var.prefix}"
  subnet_name              = "subnet-${var.prefix}"
  iothub_name              = "iothub-${var.prefix}"
  storage_account_name     = "st${var.prefix}${random_string.suffix.result}"
  storage_container_name   = "iot-data"
  asa_job_name             = "asa-${var.prefix}"
  asa_input_name           = "iothub-input"
  asa_output_name          = "blob-output"
  asa_output_sb_name       = "servicebus-output"
  consumer_group_name      = "asa-consumer-group"
  servicebus_namespace     = "sb-${var.prefix}-${random_string.suffix.result}"
  servicebus_queue_name    = "iot-notifications"
  servicebus_auth_rule     = "asa-send-rule"
  tags = {
    project     = "iot-lab"
    environment = "study"
    managed_by  = "terraform"
  }
}

# =============================================================================
# Resource Group
# =============================================================================

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

# =============================================================================
# Rede — VNet + Subnet
# =============================================================================

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  # Service endpoints permitem que o Storage e IoT Hub enxerguem a subnet
  # sem necessidade de Private Endpoints pagos
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.EventHub",
  ]
}

# =============================================================================
# IoT Hub — SKU F1 (free tier)
# =============================================================================

resource "azurerm_iothub" "hub" {
  name                = local.iothub_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = var.iot_hub_sku
    capacity = 1
  }

  # Retém mensagens por 1 dia (máximo no F1)
  event_hub_retention_in_days = 1
  event_hub_partition_count   = 2

  tags = local.tags
}

# Consumer group dedicado para o Stream Analytics
# (não compartilhar com outras aplicações evita perda de mensagens)
resource "azurerm_iothub_consumer_group" "asa_cg" {
  name                   = local.consumer_group_name
  iothub_name            = azurerm_iothub.hub.name
  eventhub_endpoint_name = "events"
  resource_group_name    = azurerm_resource_group.rg.name
}

# =============================================================================
# Dispositivos IoT — registrados via Azure CLI (local-exec)
#
# O provider azurerm não expõe um resource estável para device identity,
# portanto usamos az iot hub device-identity create.
# Requer: az extension add --name azure-iot
# =============================================================================

resource "null_resource" "iot_devices" {
  count = length(var.devices)

  triggers = {
    hub_id    = azurerm_iothub.hub.id
    device_id = var.devices[count.index]
  }

  provisioner "local-exec" {
    command = <<-EOT
      az iot hub device-identity create \
        --hub-name ${azurerm_iothub.hub.name} \
        --device-id ${var.devices[count.index]} \
        --resource-group ${azurerm_resource_group.rg.name} \
        --output none 2>/dev/null || true
    EOT
  }

  # Ao destruir, remove o dispositivo
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      az iot hub device-identity delete \
        --hub-name ${azurerm_iothub.hub.name} \
        --device-id ${self.triggers.device_id} \
        --output none 2>/dev/null || true
    EOT
  }

  depends_on = [azurerm_iothub.hub]
}

# =============================================================================
# Storage Account + Container — destino final dos dados
# =============================================================================

resource "azurerm_storage_account" "sa" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Segurança: bloquear acesso público anônimo aos blobs
  allow_nested_items_to_be_public = false

  # Aceitar conexões apenas da subnet criada acima
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.subnet.id]
  }

  tags = local.tags
}

resource "azurerm_storage_container" "container" {
  name                  = local.storage_container_name
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

# =============================================================================
# Service Bus — fila de integração para acionamento de automações (ex: Logic App)
# =============================================================================

resource "azurerm_servicebus_namespace" "sb" {
  name                = local.servicebus_namespace
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  tags = local.tags
}

resource "azurerm_servicebus_queue" "notifications" {
  name         = local.servicebus_queue_name
  namespace_id = azurerm_servicebus_namespace.sb.id

  max_delivery_count = 10
}

resource "azurerm_servicebus_namespace_authorization_rule" "asa_send" {
  name         = local.servicebus_auth_rule
  namespace_id = azurerm_servicebus_namespace.sb.id

  send   = true
  listen = false
  manage = false
}

# =============================================================================
# Stream Analytics Job — criado PARADO (não inicia automaticamente)
# =============================================================================

resource "azurerm_stream_analytics_job" "asa" {
  name                                     = local.asa_job_name
  resource_group_name                      = azurerm_resource_group.rg.name
  location                                 = azurerm_resource_group.rg.location
  streaming_units                          = 1
  data_locale                              = "pt-BR"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Stop"
  compatibility_level                      = "1.2"

    # Pass-through: encaminha todas as mensagens para Blob e Service Bus
  transformation_query = <<-SAQL
    SELECT
        *
    INTO
        [${local.asa_output_name}]
    FROM
      [${local.asa_input_name}];

    SELECT
      *
    INTO
      [${local.asa_output_sb_name}]
    FROM
      [${local.asa_input_name}]
  SAQL

  tags = local.tags
}

# Input: IoT Hub (endpoint built-in de mensagens)
resource "azurerm_stream_analytics_stream_input_iothub" "input" {
  name                         = local.asa_input_name
  stream_analytics_job_name    = azurerm_stream_analytics_job.asa.name
  resource_group_name          = azurerm_resource_group.rg.name
  endpoint                     = "messages/events"
  eventhub_consumer_group_name = azurerm_iothub_consumer_group.asa_cg.name
  iothub_namespace             = azurerm_iothub.hub.name
  shared_access_policy_key     = azurerm_iothub.hub.shared_access_policy[0].primary_key
  shared_access_policy_name    = "iothubowner"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

# Output: Blob Storage
resource "azurerm_stream_analytics_output_blob" "output" {
  name                      = local.asa_output_name
  stream_analytics_job_name = azurerm_stream_analytics_job.asa.name
  resource_group_name       = azurerm_resource_group.rg.name
  storage_account_name      = azurerm_storage_account.sa.name
  storage_account_key       = azurerm_storage_account.sa.primary_access_key
  storage_container_name    = azurerm_storage_container.container.name
  path_pattern              = "{date}/{time}"
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"
  batch_min_rows            = 0
  batch_max_wait_time       = "00:02:00"

  serialization {
    type            = "Json"
    encoding        = "UTF8"
    format          = "LineSeparated"
  }
}

# Output secundário: Service Bus Queue (integração com Logic App)
resource "azurerm_stream_analytics_output_servicebus_queue" "output_sb" {
  name                         = local.asa_output_sb_name
  stream_analytics_job_name    = azurerm_stream_analytics_job.asa.name
  resource_group_name          = azurerm_resource_group.rg.name
  servicebus_namespace         = azurerm_servicebus_namespace.sb.name
  queue_name                   = azurerm_servicebus_queue.notifications.name
  shared_access_policy_key     = azurerm_servicebus_namespace_authorization_rule.asa_send.primary_key
  shared_access_policy_name    = azurerm_servicebus_namespace_authorization_rule.asa_send.name

  serialization {
    type     = "Json"
    encoding = "UTF8"
    format   = "LineSeparated"
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "resource_group_haja_coracao" {
  description = "Haja-Coracao-Resource-Group"
  value       = azurerm_resource_group.rg.name
}

output "iothub_haja_coracao" {
  description = "Haja-Coracao-IoT-Hub"
  value       = azurerm_iothub.hub.name
}

output "iothub_hostname_haja_coracao" {
  description = "Haja-Coracao-IoT-Hub-Hostname"
  value       = azurerm_iothub.hub.hostname
}

output "iothub_owner_connection_string" {
  description = "Haja-Coracao-IoT-Hub-Connection-String"

  value       = "HostName=${azurerm_iothub.hub.hostname};SharedAccessKeyName=iothubowner;SharedAccessKey=${azurerm_iothub.hub.shared_access_policy[0].primary_key}"
  sensitive   = true
}
 
output "devices_registered" {
  description = "Haja-Coracao-Devices-Registered"
  value       = var.devices
}

output "storage_account_haja_coracao" {
  description = "Haja-Coracao-Storage-Account"
  value       = azurerm_storage_account.sa.name
}

output "storage_container_haja_coracao" {
  description = "Haja-Coracao-Blob-Container"

  value       = azurerm_storage_container.container.name
}

output "asa_job_haja_coracao" {
  description = "Haja-Coracao-Stream-Analytics-Job"
  value       = azurerm_stream_analytics_job.asa.name
}

output "servicebus_namespace_haja_coracao" {
  description = "Haja-Coracao-Service-Bus-Namespace"
  value       = azurerm_servicebus_namespace.sb.name
}

output "servicebus_queue_haja_coracao" {
  description = "Haja-Coracao-Service-Bus-Queue"
  value       = azurerm_servicebus_queue.notifications.name
}

output "portal_asa_url" {
  description = "Haja-Coracao-Stream-Analytics-Portal-URL"
  value       = "https://portal.azure.com/#resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.StreamAnalytics/streamingjobs/${azurerm_stream_analytics_job.asa.name}/overview"
}

output "test_send_message_command" {
  description = "Haja-Coracao-Test-Send-Message-Command"
  value       = "az iot device send-d2c-message --hub-name ${azurerm_iothub.hub.name} --device-id device-01 --data '{\"sensor\":\"device-01\",\"temp\":22.5,\"humidity\":60}'"
}
