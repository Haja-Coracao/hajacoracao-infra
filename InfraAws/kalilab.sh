#!/bin/bash

# script Ambiente Kali AWS - Atacante e Alvo

# 1. Limpar (Remove qualquer rastro que possa causar o erro 401)
echo "Limpando ambiente"
sudo docker rm -f kali-lab localstack-lab 2>/dev/null
sudo docker network rm lab-network 2>/dev/null

# 2. Preparação do Host
sudo apt update && sudo apt install docker.io -y
sudo docker network create lab-network

# 3. Instalação do Kali Linux - Atacante
# Usar o 'kasm_user' que é o padrão da imagem Kasm - VNC
echo "Subindo Kali Linux (Aguarde...)"
sudo docker run -d \
  --name kali-lab \
  --network lab-network \
  --privileged \
  -p 6901:6901 \
  -e VNC_PW=urubu100 \
  --shm-size=512m \
  kasmweb/kali-rolling-desktop:1.15.0

# 4. Subida do LocalStack - Alvo
sudo docker run -d \
  --name localstack-lab \
  --network lab-network \
  -p 4566:4566 \
  -e SERVICES=s3,iam \
  localstack/localstack

echo "Aguardando inicialização (30 segundos)"
sleep 30

# 5. CORREÇÃO DA CHAVE GPG (Para não travar a instalação das ferramentas)
echo "Atualizando chaves de segurança"
sudo docker exec -u 0 kali-lab apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ED65462EC8D5E4C5

# 6. SINCRONIZAÇÃO DE SENHA (evitar o Erro 401)
echo "Sincronizar senhas"
sudo docker exec -u 0 kali-lab sh -c "id kasm_user 2>/dev/null || useradd -m -s /bin/bash kasm_user"
sudo docker exec -u 0 kali-lab sh -c "id kasm-user 2>/dev/null || useradd -m -s /bin/bash kasm-user"

sudo docker exec -u 0 kali-lab sh -c "echo 'kasm_user:urubu100' | chpasswd"
sudo docker exec -u 0 kali-lab sh -c "echo 'kasm-user:urubu100' | chpasswd"
sudo docker exec -u 0 kali-lab sh -c "echo 'root:urubu100' | chpasswd"  # Adicionar senha para root

sudo docker exec -u 0 kali-lab sh -c "usermod -aG sudo kasm_user; usermod -aG sudo kasm-user"

sudo docker exec -u 0 kali-lab sh -c "grep -q '^kasm_user' /etc/sudoers || echo 'kasm_user ALL=(ALL) ALL' >> /etc/sudoers"  # Remover NOPASSWD
sudo docker exec -u 0 kali-lab sh -c "grep -q '^kasm-user' /etc/sudoers || echo 'kasm-user ALL=(ALL) ALL' >> /etc/sudoers"  # Remover NOPASSWD

# 7. INSTALAÇÃO DAS FERRAMENTAS (Com verificação)
echo "Instalar ferramentas (Autopsy, Nmap, AWS CLI)..."
sudo docker exec -u 0 kali-lab apt update
sudo docker exec -u 0 kali-lab apt install -y nmap autopsy sleuthkit awscli

# 8. FINALIZAÇÃO
echo "-------------------------------------------------------"
echo "LABORATÓRIO CONFIGURADO!"
echo "-------------------------------------------------------"
echo "URL: https://$(curl -s ifconfig.me):6901"
echo "USUÁRIO: kasm_user"
echo "SENHA: urubu100"
echo "IMPORTANTE: Se der erro 401, use JANELA ANÔNIMA."
echo "-------------------------------------------------------"
