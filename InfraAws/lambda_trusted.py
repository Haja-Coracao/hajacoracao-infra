import os
import boto3
from datetime import datetime, timezone
from urllib.parse import unquote_plus

s3 = boto3.client("s3")

def handler(event, context):
    """
    Função Lambda: Trusted → Client
    Prepara dados processados para consumo pela aplicação
    Copia dados com timestamp e organiza por atleta
    """
    dst_bucket = os.getenv("DEST_BUCKET")
    records = event.get("Records")
    results = []
    
    for r in records:
        s3_info = r.get("s3", {})
        src_bucket = s3_info.get("bucket", {}).get("name")
        src_key = s3_info.get("object", {}).get("key")
        if not src_bucket or not src_key:
            continue
        
        src_key = unquote_plus(src_key)
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        base_name = os.path.basename(src_key)
        
        # Organiza por data/hora no bucket client
        dst_key = f"ready/{timestamp}_{base_name}"
        copy_source = {"Bucket": src_bucket, "Key": src_key}
        
        try:
            s3.copy_object(CopySource=copy_source, Bucket=dst_bucket, Key=dst_key)
            print(f"[+] Dados finalizados: {src_bucket}/{src_key} → {dst_bucket}/{dst_key}")
            results.append({"source": src_key, "destination": dst_key})
        except Exception as e:
            print(f"[!] Erro ao copiar objeto: {e}")
            raise

    return {
        "status": "success",
        "message": f"Dados preparados para consumo",
        "copies": results
    }
