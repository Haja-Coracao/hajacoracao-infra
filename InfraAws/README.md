# 🏃 Haja Coração - Infraestrutura AWS

Infraestrutura de Data Lake na AWS para o projeto **Haja Coração** - Sistema de monitoramento em tempo real de batida cardíaca (BPM) de atletas de futebol.

## 📋 Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    Infraestrutura AWS                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  EC2 Jupyter     │  │  EC2 Grafana     │                │
│  │ (Data Ingestion) │  │ (Visualization)  │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                     │                            │
│           └──────────┬──────────┘                            │
│                      │                                       │
│          ┌───────────▼──────────┐                           │
│          │   S3 Data Lake       │                           │
│          ├──────────────────────┤                           │
│          │ Raw (dados brutos)   │◄───────────┐             │
│          │ Trusted (processado) │            │             │
│          │ Client (final)       │            │             │
│          └──────────┬───────────┘            │             │
│                     │                        │             │
│          ┌──────────▼──────────┐        ┌───────────┐      │
│          │  Lambda Functions   │        │ EC2 Kali  │      │
│          ├──────────────────────┤        │(Security) │      │
│          │ Raw→Trusted         │        └───────────┘      │
│          │ Trusted→Client      │                            │
│          └─────────────────────┘                            │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Componentes

### **EC2 Instances**
- **Data Integration (Jupyter)**: `t3.small` - Jupyter Notebook para ingestão e processamento inicial de dados
- **Grafana**: `t3.medium` - Dashboard de visualização de BPM em tempo real
- **Kali**: `t3.medium` - Ambiente isolado para testes de segurança

### **S3 Data Lake**
- **Bucket RAW**: Dados brutos recebidos dos sensores/wearables
- **Bucket TRUSTED**: Dados validados e processados
- **Bucket CLIENT**: Dados finalizados para consumo pela aplicação

### **Lambda Functions**
- **Raw → Trusted**: Processa e valida dados brutos
- **Trusted → Client**: Prepara dados para consumo da aplicação

### **Security**
- Security Groups para cada serviço
- Geração automática de chaves SSH (RSA 2048-bit)

## 📋 Pré-requisitos

### **Localmente**
- Terraform >= 1.2
- AWS CLI configurado
- Credenciais AWS (configure com `aws configure`)
- Token de sessão (configure com `aws configure set aws_session_token <seu_token>`)
- Arquivo `.pem` PEM para acesso SSH

### **Ambiente AWS**
- Subscription com permissão para criar:
  - EC2 instances
  - S3 buckets
  - Lambda functions
  - IAM roles/permissions

## 🛠️ Configuração Inicial

### 1. **Clonar/Preparar o repositório**
```bash
cd InfraAws
```

### 2. **Verificar arquivos necessários**

Certifique-se de que os seguintes scripts existem no diretório:
```bash
ls -la
# Esperado:
# - data_integration_setup.sh     (setup Jupyter)
# - grafana_setup.sh               (setup Grafana)
# - kalilab.sh                     (setup Kali)
# - lambda_raw.py                  (função Lambda Raw→Trusted)
# - lambda_trusted.py              (função Lambda Trusted→Client)
# - dados-teste.csv                (arquivo de teste)
# - dados.py                       (script de teste PySpark)
```

### 3. **Customizar variáveis**

Edite `variables.tf` e adapte conforme necessário:
```hcl
variable "bucket_raw_haja_coracao" {
  default = "haja-coracao-raw-seu-sufixo"  # Deve ser único globalmente
}

variable "bucket_trusted_haja_coracao" {
  default = "haja-coracao-trusted-seu-sufixo"
}

variable "bucket_client_haja_coracao" {
  default = "haja-coracao-client-seu-sufixo"
}
```

### 4. **Inicializar Terraform**
```bash
terraform init
```

## 🚀 Deployment

### **Aplicar configuração**
```bash
terraform apply -auto-approve
```

**⏳ Aguarde aproximadamente 7-10 minutos** para que todas as instâncias iniciem e os serviços estejam prontos.

## 📊 Acessar Serviços

Após o deployment, os IPs públicos serão exibidos nos outputs:

```
Outputs:

url_jupyter = "http://<IP_JUPYTER>:80"
url_grafana = "http://<IP_GRAFANA>:3000"
url_kali = "https://<IP_KALI>:6901"

bucket_raw_name = "haja-coracao-raw-xxxxxxxx"
bucket_trusted_name = "haja-coracao-trusted-xxxxxxxx"
bucket_client_name = "haja-coracao-client-xxxxxxxx"
```

### **Jupyter Notebook**
```
URL: http://<IP_JUPYTER>:80
```
Acesse para fazer ingestão e testes de dados

### **Grafana**
```
URL: http://<IP_GRAFANA>:3000
Usuário padrão: admin
Senha padrão: admin
```
Configure data sources apontando para os buckets S3

### **Kali (Testes de Segurança)**
```
URL: https://<IP_KALI>:6901
```
Ambiente isolado para testes de segurança

## 📝 Fluxo de Dados

1. **Ingestão (Data Integration)**: Dados brutos enviados para `bucket-raw`
2. **Processamento (Lambda Raw)**: Automaticamente acionada ao detectar novo objeto em Raw
3. **Validação (Trusted)**: Dados processados movidos para `bucket-trusted`
4. **Consumo (Lambda Trusted)**: Dados finalizados preparados em `bucket-client`
5. **Visualização (Grafana)**: Dashboard consome dados do `bucket-client`

## 🔐 Segurança

- Chaves SSH geradas automaticamente
- Security Groups restritivos por serviço
- Acesso SSH apenas de IPs autorizados
- Sem credenciais hard-coded (utiliza IAM Profile)

## 🧹 Destruir Infraestrutura

```bash
terraform destroy -auto-approve
```

**⚠️ Atenção**: Todos os dados nos buckets S3 serão **PERMANENTEMENTE DELETADOS**. Certifique-se de fazer backup antes de destruir.

## 📂 Estrutura de Arquivos

```
InfraAws/
├── main.tf                      # Definição principal de recursos
├── variables.tf                 # Variáveis de configuração
├── data_integration_setup.sh     # Script de setup do Jupyter
├── grafana_setup.sh              # Script de setup do Grafana
├── kalilab.sh                    # Script de setup do Kali
├── lambda_raw.py                 # Função Lambda Raw→Trusted
├── lambda_trusted.py             # Função Lambda Trusted→Client
├── dados.py                      # Script auxiliar de dados
├── dados-teste.csv               # Arquivo CSV de teste
└── README.md                     # Este arquivo
```

## 🐛 Troubleshooting

### **Erro: "LabRole não encontrada"**
```
Solução: Certifique-se de que está usando uma subscription com LabRole pré-criada
ou adicione uma role IAM manualmente.
```

### **EC2 não inicia serviços**
```
Aguarde 5-10 minutos - o user_data script está sendo executado
SSH na instância e verifique: sudo tail -f /var/log/cloud-init-output.log
```

### **Lambda não dispara automaticamente**
```
Verifique:
1. aws_lambda_permission está criada
2. aws_s3_bucket_notification está configurada
3. Arquivo sendo uploaded tem a extensão correta (.csv)
```

## 📞 Suporte

Para problemas, verifique:
- Status das instâncias EC2 no console AWS
- Logs de cloud-init: `sudo tail -f /var/log/cloud-init-output.log`
- Logs de Lambda no CloudWatch
- Triggers de S3 no console da Lambda

## 📄 Licença

Projeto Haja Coração - 2024
