# 📋 PROJETO METATRON 3.0 - GUIA SETUP PASSO A PASSO

## 📌 Objetivo
Implantar uma infraestrutura completa em AWS com:
- **Kali Linux**: Nó de ataque e ingestão de dados (APIs + Simulador)
- **Data Integration**: EC2 com JupyterLab + PySpark para análise
- **Grafana**: Dashboard para visualização de dados
- **Data Lake**: S3 com 3 camadas (Raw → Trusted → Client)
- **Lambda**: Transformações automáticas entre camadas
- **Amazon Athena**: Motor SQL para consultas

---

## 🔧 PRÉ-REQUISITOS

### 1. **Ferramentas Locais Necessárias**
```bash
# Instale (Windows):
# - Terraform: https://www.terraform.io/downloads.html
# - AWS CLI: https://aws.amazon.com/pt/cli/
# - Git: https://git-scm.com/
# - Python 3.10+: https://www.python.org/

# Verificar instalações:
terraform version
aws --version
python3 --version
```

### 2. **Conta AWS Educate**
- Acesse: https://www.awseducate.com/
- Faça login com credenciais de estudante
- Abra a sessão de laboratório (AWS Details)
- **Copie e guarde**: Access Key, Secret Key, Session Token

### 3. **Chave PEM do Lab**
No console AWS Educate → AWS Details → Download PEM
- Nomeie como: `labuser.pem`
- Guarde em local seguro

---

## 🏗️ PASSO 1: CONFIGURAR AWS CREDENTIALS

### No PowerShell (Windows):
```powershell
# Configure as credenciais da AWS
aws configure

# Será solicitado:
# AWS Access Key ID: [Cole aqui]
# AWS Secret Access Key: [Cole aqui]
# Default region name: us-east-1
# Default output format: json
```

### Adicionar Session Token (AWS Educate):
```powershell
aws configure set aws_session_token "YOUR_SESSION_TOKEN_HERE"

# Verificar configuração:
aws s3 ls
# Se retornar lista de buckets = OK!
```

---

## 📦 PASSO 2: PREPARAR AMBIENTE LOCAL

### Clone/Navegue até a pasta do projeto:
```powershell
cd c:\Users\lucas\Documents\Infra_Projeto\InfraAws

# Verificar arquivos necessários:
# ✅ main.tf
# ✅ variables.tf
# ✅ dados.py
# ✅ dados-teste.csv
# ✅ grafana_setup.sh
# ✅ kali_userdata.tpl
# ✅ kalilab.sh
# ✅ lambda_raw.py
# ✅ lambda_trusted.py
# ✅ Scripts_Pipeline_Kali/ (pasta)
```

### Criar Virtual Environment (opcional, recomendado):
```powershell
python3 -m venv .venv
.\.venv\Scripts\Activate.ps1

# Instalar dependências Python (se necessário):
pip install --upgrade boto3 requests
```

---

## 🚀 PASSO 3: INICIALIZAR TERRAFORM

### Dentro da pasta InfraAws:
```powershell
# Baixar providers Terraform
terraform init

# Validar configuração
terraform validate

# Ver plano de deployment (sem executar):
terraform plan

# Resultado esperado:
# Plan: 23 to add, 0 to change, 0 to destroy.
```

---

## 💥 PASSO 4: APLICAR INFRAESTRUTURA (DEPLOY)

### Executar com auto-approve:
```powershell
terraform apply -auto-approve

# Aguarde 7-10 minutos!
# Terraform criará:
# ✅ EC2 Kali (com Docker + ferramentas)
# ✅ EC2 Data Integration (com JupyterLab + PySpark)
# ✅ EC2 Grafana
# ✅ 3 Buckets S3 (raw, trusted, client)
# ✅ 2 Funções Lambda (transformação de dados)
# ✅ API Gateway (upload de arquivos)
```

### Copiar Outputs:
Após o `terraform apply` completar, você receberá:
```
Outputs:

api_gateway_url = "https://xxxxx.execute-api.us-east-1.amazonaws.com/hmg"
bucket_client_name = "metatron-client-xxxxx"
bucket_raw_name = "metatron-raw-xxxxx"
bucket_trusted_name = "metatron-trusted-xxxxx"
ec2_data_integration_ip = "1.2.3.4"
ec2_grafana_ip = "5.6.7.8"
ec2_kali_ip = "9.10.11.12"
lambda_raw_function_name = "lambda-raw-to-trusted-haja-coracao"
lambda_trusted_function_name = "lambda-trusted-to-client-haja-coracao"
url_grafana = "http://5.6.7.8:3000"
url_jupyter = "http://1.2.3.4:80"
url_kali = "https://9.10.11.12:6901"
```

---

## 🔐 PASSO 5: ACESSAR KALI (APÓS ~7 MINUTOS)

### Via Browser:
```
URL: https://<ec2_kali_ip>:6901
Usuário: kasm_user
Senha: urubu100

⚠️ Se der erro 401: Use janela anônima (Ctrl+Shift+P em Chrome/Edge)
```

### Dentro do Kali, executar pipeline:
```bash
# Acessar terminal do Kali
cd ~/Scripts_Pipeline_Kali

# 1. Verificar conexão com S3
aws configure
# (Copie credenciais AWS Educate)

# 2. Iniciar API de ingestão
python3 api_ingestao.py
# Resultado: "API BPM rodando em http://0.0.0.0:5000"

# Em outro terminal:
# 3. Executar simulador (em paralelo)
python3 simulador_agrodados_poison.py

# Você verá:
# [OK] HTTP 200 | athlete-01 - BPM: 85.32
# [OK] HTTP 200 | athlete-02 - BPM: 120.15
# ... (dados sendo salvos no S3 Raw)
```

---

## 📊 PASSO 6: CONFIGURAR GRAFANA + ATHENA

### 6.1 Acessar Grafana (APÓS ~2-5 MINUTOS):
```
URL: http://<ec2_grafana_ip>:3000
Usuário padrão: admin
Senha padrão: admin
```

### 6.2 Adicionar Data Source (Amazon Athena):

1. **Menu → Data Sources → Add new data source**
2. **Busque: "Amazon Athena"** (não SQL Server ou BigQuery!)
3. **Preencha:**
   - Authentication Type: Access & Secret Key
   - Access Key ID: [Cole da AWS Educate]
   - Secret Access Key: [Cole da AWS Educate]
   - Region: us-east-1
   - Output Location: `s3://<seu-bucket-raw>/results/`

4. **Save & Test** → Deve retornar verde ✅

### 6.3 Criar Query no Athena:

1. **Dashboard → Create → Panel**
2. **Query → Selecione "Athena" na dropdown**
3. **Cole a query:**
```sql
SELECT 
  athlete_id,
  bpm,
  timestamp,
  estado
FROM telemetry 
ORDER BY timestamp DESC 
LIMIT 100
```

4. **Run** → Dados aparecem na tabela
5. **Visualization: Graph/Gauge** (conforme preferir)

---

## 📁 PASSO 7: TESTAR DATA LAKE (LAMBDA)

### Verificar transformações automáticas:

```powershell
# No PowerShell, verificar buckets:
aws s3 ls s3://<bucket-raw-name>/
# Verá: JSON files com dados de BPM

aws s3 ls s3://<bucket-trusted-name>/
# Lambda processou e moveu arquivos

aws s3 ls s3://<bucket-client-name>/
# Lambda final processou e moveu
```

### No Console AWS:
1. Acesse: **S3 → Buckets**
2. Veja objetos em Raw, Trusted, Client
3. Abra CloudWatch → Lambda Logs para validar execução

---

## 🧪 PASSO 8: VALIDAÇÃO COMPLETA

### Checklist:
- [ ] Terraform Deploy OK (`terraform apply` completou sem erros)
- [ ] Kali acessível em `https://<IP>:6901` (aguarde 7 min)
- [ ] Jupyter acessível em `http://<IP>:80`
- [ ] Grafana acessível em `http://<IP>:3000`
- [ ] API Flask rodando em Kali (porta 5000)
- [ ] Simulador enviando dados ao S3
- [ ] Arquivos em Raw bucket
- [ ] Lambda acionada (verificar CloudWatch Logs)
- [ ] Athena Data Source conectado em Grafana
- [ ] Dashboard mostrando dados do Athena

---

## 🗑️ PASSO 9: LIMPEZA (QUANDO TERMINAR)

### ⚠️ IMPORTANTE: Destruir recursos para evitar custos!

```powershell
cd c:\Users\lucas\Documents\Infra_Projeto\InfraAws

# Destruir toda infraestrutura
terraform destroy -auto-approve

# Aguarde 5 minutos para destruir

# Verificar que tudo foi removido:
aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId,State.Name]"
# Resultado: lista vazia
```

---

## 🐛 TROUBLESHOOTING

### Erro 401 no Kali:
```
Solução: Usar janela anônima do navegador
```

### API Flask não responde:
```bash
# Dentro do Kali, verificar se porta 5000 está aberta:
netstat -tlnp | grep 5000
# Se não retornar nada, reiniciar:
python3 api_ingestao.py
```

### Grafana não consegue conectar ao Athena:
```
1. Verificar credentials AWS (acesso-chave correta)
2. Verificar que s3://bucket/results/ existe e tem permissão
3. Verificar Security Group da EC2 (porta 443 outbound = HTTPS)
```

### Lambda não acionada:
```
1. Verificar S3 Bucket Notifications (deve estar habilitada)
2. Verificar CloudWatch Logs: /aws/lambda/lambda-raw-to-trusted-haja-coracao
3. Verificar IAM Role do Lambda (LabRole tem permissão S3?)
```

### Buckets não criados:
```powershell
# Verificar limites de bucket:
aws s3 ls
# Se erro: "User is not authorized"
# → Verificar AWS Session Token (expirou?)
aws configure set aws_session_token "NEW_TOKEN_HERE"
```

---

## 📚 ESTRUTURA FINAL ESPERADA

```
Infra Azure/
  └─ main.tf

InfraAws/
  ├─ main.tf ........................ Definição completa AWS
  ├─ variables.tf ................... Variáveis (nomes, tipos)
  ├─ dados.py ....................... Script Python
  ├─ dados-teste.csv ................ Dados de teste
  ├─ grafana_setup.sh ............... Setup Grafana
  ├─ kali_userdata.tpl .............. User data Kali
  ├─ kalilab.sh ..................... Script Kali
  ├─ lambda_raw.py .................. Função Lambda Raw→Trusted
  ├─ lambda_trusted.py .............. Função Lambda Trusted→Client
  ├─ SETUP.md ....................... ← VOCÊ ESTÁ AQUI
  ├─ Scripts_Pipeline_Kali/
  │  ├─ api_ingestao.py ............ API Flask (porta 5000)
  │  ├─ simulador_agrodados_poison.py . Simulador de dados
  │  └─ dashboard_exporter_pynb.py ... Exportador dashboard
  ├─ Teste_PySpark/
  │  └─ pyspark_test.ipynb ......... Notebook PySpark
  └─ terraform.tfstate ............. Estado Terraform
```

---

## 🎯 ARQUITETURA FINAL

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS EDUCATE LAB                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │   EC2 KALI       │  │  EC2 DATA INTEG  │  │  EC2 GRAFANA │  │
│  │ (Atacante/IoT)   │  │  (JupyterLab)    │  │  (Dashboard) │  │
│  │ - API Port 5000  │  │ - PySpark        │  │ - Port 3000  │  │
│  │ - Simulador      │  │ - Jupyter Port80 │  │ - Athena DS  │  │
│  │ - Tools (Nmap)   │  │                  │  │              │  │
│  └────────┬─────────┘  └──────────────────┘  └────────┬──────┘  │
│           │                    │                       │         │
│           └────────────────────┼───────────────────────┘         │
│                                │                                  │
│                   ┌────────────▼──────────────┐                  │
│                   │      S3 DATA LAKE         │                  │
│                   ├───────────────────────────┤                  │
│                   │ Raw (Bruto) ◄── Lambda   │                  │
│                   │     ↓                     │                  │
│                   │ Trusted ◄── Lambda       │                  │
│                   │     ↓                     │                  │
│                   │ Client (Finalizado)      │                  │
│                   └───────────────────────────┘                  │
│                                │                                  │
│                    ┌───────────▼──────────┐                     │
│                    │  Amazon Athena       │                     │
│                    │  (SQL Queries)       │                     │
│                    └────────────┬─────────┘                     │
│                                 │                                │
│                    ┌────────────▼──────────┐                    │
│                    │ Grafana Dashboard    │                    │
│                    │ - Gauge (Temperatura)│                    │
│                    │ - Graph (Histórico)  │                    │
│                    │ - Alerts             │                    │
│                    └──────────────────────┘                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📞 SUPORTE

### Verificar Logs:
```powershell
# Terraform Logs
terraform show

# AWS CloudWatch (EC2 User Data)
aws ec2 get-console-output --instance-id i-xxxxxxxxx --region us-east-1

# Lambda Logs
aws logs tail /aws/lambda/lambda-raw-to-trusted-haja-coracao --follow
```

### Documentação:
- [Metatron 3.0 Guide (PDF)](./IMPLEMENTACOES.md)
- [AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Amazon Athena Documentation](https://docs.aws.amazon.com/athena/)

---

**Criado para Projeto Metatron 3.0 - HAJA CORAÇÃO**
**Data: 2026-06-08**
**Status: ✅ Pronto para Deploy**
