#!/bin/bash
set -eux

# Update system
apt-get update
apt-get install -y gnupg software-properties-common wget apt-transport-https

# Add Grafana GPG key and repository
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list

# Install Grafana
apt-get update
apt-get install -y grafana

# Enable and start Grafana
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

sleep 5

echo "=== Grafana installed and started ==="
echo "Default credentials: admin / admin"
echo "Access Grafana at: http://localhost:3000"
