from flask import Flask, request, jsonify
import boto3
import json
import datetime
import os

app = Flask(__name__)

# Configuração da AWS
REGIAO = 'us-east-1'
NOME_BUCKET = os.getenv("NOME_BUCKET", "SEU-BUCKET-RAW")

# Inicia o cliente S3
s3_client = boto3.client('s3', region_name=REGIAO)


@app.route('/api/bpm', methods=['POST'])
def receber_bpm():
    """Recebe dados de BPM de atletas e armazena no S3"""
    try:
        dados = request.json

        # Valida campos obrigatórios
        if 'athlete_id' not in dados or 'bpm' not in dados:
            return jsonify({"erro": "Campos obrigatórios: athlete_id, bpm"}), 400

        # Gera nome de arquivo único baseado no timestamp
        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S%f")
        athlete_id = dados.get('athlete_id', 'unknown')
        nome_arquivo = f"bpm_{athlete_id}_{timestamp}.json"

        # Upload do JSON para S3
        s3_client.put_object(
            Bucket=NOME_BUCKET,
            Key=nome_arquivo,
            Body=json.dumps(dados),
            ContentType='application/json'
        )

        print(f"[+] Novo dado BPM recebido: {athlete_id} - {dados.get('bpm')} BPM")
        return jsonify({
            "status": "sucesso",
            "mensagem": "Dado BPM armazenado no S3",
            "arquivo": nome_arquivo
        }), 200

    except Exception as e:
        print(f"[!] Erro ao salvar BPM: {str(e)}")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check da API"""
    return jsonify({"status": "online", "servico": "api-bpm-haja-coracao"}), 200


if __name__ == '__main__':
    print("=== API BPM - HAJA CORAÇÃO INICIADA ===")
    print(f"Bucket S3: {NOME_BUCKET}")
    print("Aguardando requisições em http://0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000)
