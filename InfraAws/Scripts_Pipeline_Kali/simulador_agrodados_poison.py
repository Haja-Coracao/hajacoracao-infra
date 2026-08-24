import time
import json
import random
import requests

# API que está rodando localmente
API_URL = "http://127.0.0.1:5000/api/bpm"
ATHLETES = ["athlete-01", "athlete-02", "athlete-03", "athlete-04", "athlete-05"]
HEADERS = {'Content-Type': 'application/json', 'User-Agent': 'Haja-Coracao-Simulator/1.0'}


def gerar_bpm_normal(athlete_id):
    """Gera BPM normal de um atleta (60-120)"""
    return {
        "athlete_id": athlete_id,
        "bpm": round(random.uniform(60.0, 120.0), 2),
        "timestamp": int(time.time()),
        "estado": "normal"
    }


def gerar_bpm_anomalia(athlete_id, tipo_anomalia="taquicardia"):
    """Gera BPM anômalo para testes de segurança"""
    if tipo_anomalia == "taquicardia":
        # BPM muito alto (> 150)
        return {
            "athlete_id": athlete_id,
            "bpm": round(random.uniform(150.0, 200.0), 2),
            "timestamp": int(time.time()),
            "estado": "taquicardia"
        }
    elif tipo_anomalia == "bradicardia":
        # BPM muito baixo (< 40)
        return {
            "athlete_id": athlete_id,
            "bpm": round(random.uniform(10.0, 40.0), 2),
            "timestamp": int(time.time()),
            "estado": "bradicardia"
        }
    elif tipo_anomalia == "injection":
        # Tentativa de command injection
        return {
            "athlete_id": athlete_id,
            "bpm": "'; DROP TABLE athletes; --",
            "timestamp": int(time.time()),
            "estado": "attack_injection"
        }


def enviar_dados(payload):
    """Envia dados para a API"""
    try:
        response = requests.post(API_URL, data=json.dumps(payload), headers=HEADERS, timeout=5)
        status_icon = "[OK]" if response.status_code == 200 else "[ERRO]"
        print(f"{status_icon} HTTP {response.status_code} | {payload.get('athlete_id')} - BPM: {payload.get('bpm')}")
    except requests.exceptions.RequestException as e:
        print(f"[!] Erro de conexão: {e}")


def simular_atletas_normais(num_eventos=10):
    """Simula BPM normal de atletas"""
    print(f"\n[+] Simulando {num_eventos} eventos BPM normais...")
    for i in range(num_eventos):
        athlete = random.choice(ATHLETES)
        payload = gerar_bpm_normal(athlete)
        enviar_dados(payload)
        time.sleep(0.5)


def simular_anomalias(num_eventos=5):
    """Simula anomalias de BPM"""
    print(f"\n[+] Simulando {num_eventos} anomalias de BPM...")
    anomalias = ["taquicardia", "bradicardia", "injection"]
    for i in range(num_eventos):
        athlete = random.choice(ATHLETES)
        anomalia = random.choice(anomalias)
        payload = gerar_bpm_anomalia(athlete, anomalia)
        enviar_dados(payload)
        time.sleep(0.5)


def main():
    print("=== SIMULADOR BPM - HAJA CORAÇÃO ===")
    print(f"API: {API_URL}")
    print(f"Atletas: {ATHLETES}\n")
    
    # Simula dados normais
    simular_atletas_normais(num_eventos=20)
    
    time.sleep(2)
    
    # Simula anomalias
    simular_anomalias(num_eventos=10)
    
    print("\n[+] Simulação concluída!")


if __name__ == '__main__':
    main()
