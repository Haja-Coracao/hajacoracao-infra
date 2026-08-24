import time
import random
import os

def gerar_carga():
    print("Iniciando loop de ingestao de dados no bucket 'stage-raw'")
    
    for i in range(1, 11):  # Vamos gerar 10 arquivos
        # BPM em treino intenso (faixa tipica: 120 a 190)
        if random.random() > 0.2:
            bpm = random.randint(120, 190)
            status_bpm = "CONFORME"
        else:
            bpm = 999  # Valor impossivel (ataque/falha)
            status_bpm = "ATTACK_INJECTION_TEST"

        # Variabilidade (ms) em treino (faixa tipica: 20 a 80)
        if random.random() > 0.15:
            hrv_ms = round(random.uniform(20.0, 80.0), 2)
            status_hrv = "CONFORME"
        else:
            hrv_ms = -1.0  # Valor impossivel (ataque/falha)
            status_hrv = "ATTACK_INJECTION_TEST"

        # Saturacao O2 (%) durante esforco (faixa tipica: 94 a 99)
        if random.random() > 0.15:
            spo2 = round(random.uniform(94.0, 99.0), 2)
            status_spo2 = "CONFORME"
        else:
            spo2 = 999.99  # Valor impossivel (ataque/falha)
            status_spo2 = "ATTACK_INJECTION_TEST"

        filename = f"atleta_{i}.json"
        payload = (
            f'{{"sensor": "cardio-sensor-01", "atleta_id": "athlete-{i:03d}", '
            f'"bpm": {bpm}, "bpm_status": "{status_bpm}", '
            f'"hrv_ms": {hrv_ms}, "hrv_status": "{status_hrv}", '
            f'"spo2": {spo2}, "spo2_status": "{status_spo2}"}}'
        )

        comando = f"curl -s -X PUT 'http://localstack-lab:4566/stage-raw/{filename}' -H 'Host: s3.localhost.localstack.cloud' -d '{payload}'"
        os.system(comando)
        
        print(
            f"[{i}] Atleta: athlete-{i:03d} | BPM: {bpm} ({status_bpm}) | "
            f"HRV: {hrv_ms}ms ({status_hrv}) | SpO2: {spo2}% ({status_spo2})"
        )
        time.sleep(0.5)

    print("\nCarga de dados finalizada.")

gerar_carga()