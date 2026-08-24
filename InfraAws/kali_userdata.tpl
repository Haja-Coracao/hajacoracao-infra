#!/bin/bash
set -e

export BUCKET_RAW="${bucket_raw_name}"

sudo apt install -y unzip
mkdir -p /home/ubuntu/Scripts_Pipeline_Kali

cat <<'EOF' >/tmp/kali_pipeline.zip
${scripts_zip_b64}
EOF

base64 -d /tmp/kali_pipeline.zip > /tmp/kali_pipeline.zip.bin
unzip -o /tmp/kali_pipeline.zip.bin -d /home/ubuntu/Scripts_Pipeline_Kali
chown -R ubuntu:ubuntu /home/ubuntu/Scripts_Pipeline_Kali
rm -f /tmp/kali_pipeline.zip /tmp/kali_pipeline.zip.bin

cat <<'EOF' >/tmp/kalilab.sh
${kalilab_sh}
EOF

chmod +x /tmp/kalilab.sh
bash /tmp/kalilab.sh
