#!/bin/bash

echo "+---------------------------------------------------+"
echo "| Iniciando configuração do Data Integration na EC2 |"
echo "+---------------------------------------------------+"

set -ex

### System dependencies
sudo apt-get update -y
sudo apt-get install -y \
  openjdk-17-jdk \
  python3 \
  python3-pip \
  curl

### Python packages (latest)
python3 -m pip install --upgrade pip
python3 -m pip install --no-cache-dir \
  pyspark==3.5.7 \
  jupyterlab \
  pandas \
  openpyxl

### Directories
mkdir -p /opt/jupyter/notebook
mkdir -p /opt/jupyter/script

### Generate password hash ONCE
JUPYTER_PASSWORD_HASH=$(
  python3 - <<EOF
from jupyter_server.auth import passwd
print(passwd("urubu100"))
EOF
)

### Start script
cat <<EOF > /opt/jupyter/script/start.sh
#!/bin/bash
exec /usr/bin/python3 -m jupyter lab \\
  --ServerApp.root_dir=/opt/jupyter/notebook \\
  --ServerApp.password='$JUPYTER_PASSWORD_HASH' \\
  --ServerApp.allow_root=True \\
  --ServerApp.ip=0.0.0.0 \\
  --ServerApp.port=80 \\
  --ServerApp.open_browser=False
EOF

sudo chmod +x /opt/jupyter/script/start.sh

### systemd service
cat <<EOF > /lib/systemd/system/jupyter.service
[Unit]
Description=JupyterLab
After=network.target

[Service]
Type=simple
ExecStart=/opt/jupyter/script/start.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

### Enable service
sudo systemctl daemon-reload
sudo systemctl enable jupyter
sudo systemctl start jupyter
