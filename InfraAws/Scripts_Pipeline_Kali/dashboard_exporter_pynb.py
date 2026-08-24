# -*- coding: utf-8 -*-
"""
Dashboard Exporter - Prometheus Metrics
Exporta métricas de BPM para Prometheus
"""

import boto3
from flask import Flask, Response
import os

app = Flask(__name__)
s3 = boto3.client('s3')

BUCKET_NAME = os.getenv('BUCKET_NAME', 'SEU-BUCKET-TRUSTED')
PREFIX = 'processed_bpm/'

@app.route('/metrics')
def metrics():
    """Exporta métricas de BPM em formato Prometheus"""
    total_registros = 0
    total_anomalias = 0

    try:
        # Lista objetos no S3
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=BUCKET_NAME, Prefix=PREFIX)

        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    key = obj['Key']
                    total_registros += 1
                    
                    # Conta anomalias (BPM > 150 ou < 40)
                    if 'anomaly_' in key:
                        total_anomalias += 1

    except Exception as e:
        print(f"Erro ao ler S3: {e}")

    # Formata resposta em Prometheus OpenMetrics
    prometheus_data = (
        f"# HELP haja_coracao_bpm_records_total Total de registros de BPM processados\n"
        f"# TYPE haja_coracao_bpm_records_total counter\n"
        f"haja_coracao_bpm_records_total {total_registros}\n\n"
        f"# HELP haja_coracao_bpm_anomalies_total Total de anomalias detectadas\n"
        f"# TYPE haja_coracao_bpm_anomalies_total counter\n"
        f"haja_coracao_bpm_anomalies_total {total_anomalias}\n"
    )

    return Response(prometheus_data, mimetype='text/plain')


if __name__ == '__main__':
    print("=== Dashboard Exporter - HAJA CORAÇÃO ===")
    app.run(host='0.0.0.0', port=8000)
