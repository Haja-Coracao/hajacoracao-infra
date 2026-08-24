import os
import json
import boto3
from datetime import datetime, timezone, timedelta
from urllib.parse import unquote_plus

s3 = boto3.client("s3")

BRT = timezone(timedelta(hours=-3))
HEADER = "Datetime;Athlete;BPM;HeartRate_Status\n"


def handler(event, context):
    """
    Função Lambda: Raw → Trusted
    Processa dados brutos de BPM e validação básica
    Salva em arquivo CSV consolidado
    """
    dst_bucket = os.getenv("DEST_BUCKET")
    records = event.get("Records", [])

    for r in records:
        s3_info = r.get("s3", {})
        src_bucket = s3_info.get("bucket", {}).get("name")
        src_key = s3_info.get("object", {}).get("key")
        if not src_bucket or not src_key:
            raise ValueError(f"Evento S3 inválido: bucket='{src_bucket}', key='{src_key}'. Verifique a configuração do trigger.")
        
        src_key = unquote_plus(src_key)
        obj = s3.get_object(Bucket=src_bucket, Key=src_key)
        payload = json.loads(obj["Body"].read())

        # Extrai dados de BPM
        athlete_id = payload.get("athlete_id", "unknown")
        bpm = payload.get("bpm", 0)
        
        # Classifica status do BPM
        if bpm > 150:
            status = "TAQUICARDIA"
        elif bpm < 40:
            status = "BRADICARDIA"
        else:
            status = "NORMAL"

        now = datetime.now(BRT)
        csv_key = f"bpm_data_{now.strftime('%m_%Y')}.csv"
        timestamp = now.strftime("%Y-%m-%d %H:%M:%S")

        # Tenta ler CSV existente no TRUSTED
        try:
            existing = s3.get_object(Bucket=dst_bucket, Key=csv_key)
            csv_content = existing["Body"].read().decode("utf-8")
            if not csv_content.startswith(HEADER):
                print(f"AVISO: header ausente ou incorreto em {csv_key}. Adicionando header.")
                csv_content = HEADER + csv_content
        except s3.exceptions.NoSuchKey:
            csv_content = HEADER

        csv_content += f"{timestamp};{athlete_id};{bpm};{status}\n"
        s3.put_object(Bucket=dst_bucket, Key=csv_key, Body=csv_content.encode("utf-8"))
        print(f"[+] Atualizado {dst_bucket}/{csv_key} com dados de {athlete_id} (BPM: {bpm})")

    return {"status": "success", "message": "Dados de BPM processados e validados"}
