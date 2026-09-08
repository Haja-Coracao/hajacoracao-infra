import pandas as pd
import random
from datetime import datetime, timedelta

class HeartRateSimulator:
    def __init__(self):
        self.estadoAtual = 0
        self.contador = 0
        self.bpmAtual = 75
        self.bpmAlvo = 75
        self.nomes_estados = ["Descanso", "Aquecimento", "Corrida leve", "Intensidade", "Sprint"]

    def resetar_batimento(self):
        self.estadoAtual = 0
        self.contador = 0
        self.bpmAtual = 75
        self.bpmAlvo = 75

    def gerar_alvo(self):
        estado = self.estadoAtual
        if estado == 0: return random.randint(60, 89)
        if estado == 1: return random.randint(90, 110)
        if estado == 2: return random.randint(110, 139)
        if estado == 3: return random.randint(140, 164)
        if estado == 4: return random.randint(165, 190)
        return 75

    def atualizar_estado(self):
        chance = random.randint(0, 99)
        estado = self.estadoAtual
        if estado == 0 and chance < 30: self.estadoAtual += 1
        elif estado == 1:
            if chance < 20: self.estadoAtual -= 1
            elif chance >= 70: self.estadoAtual += 1
        elif estado == 2:
            if chance < 25: self.estadoAtual -= 1
            elif chance >= 75: self.estadoAtual += 1
        elif estado == 3 and chance < 40: self.estadoAtual -= 1
        elif estado == 4 and chance < 40: self.estadoAtual -= 1

    def ajustar_gradualmente(self):
        if self.bpmAtual < self.bpmAlvo:
            self.bpmAtual = min(self.bpmAtual + 3, self.bpmAlvo)
        elif self.bpmAtual > self.bpmAlvo:
            self.bpmAtual = max(self.bpmAtual - 3, self.bpmAlvo)

    def gerar_batimento(self):
        self.contador += 1
        if self.contador % 3 == 0:
            self.atualizar_estado()
            self.bpmAlvo = self.gerar_alvo()
        self.ajustar_gradualmente()
        return self.bpmAtual

    def get_nome_estado(self):
        return self.nomes_estados[self.estadoAtual]

DEVICES = [
    "device-01", "device-02", "device-03",
    "device-04", "device-05", "device-06"
]

def gerar_dados_excel(num_registros=500, nome_arquivo="/home/ubuntu/dados_batimentos.xlsx"):
    simulador = HeartRateSimulator()
    dados = []
    inicio = datetime.now() - timedelta(hours=num_registros // 60)

    for i in range(num_registros):
        idx = i % len(DEVICES)
        bpm = simulador.gerar_batimento()
        dados.append({
            "messageId": i + 1,
            "deviceId": DEVICES[idx],
            "heartRate": float(bpm),
            "heartRateTarget": float(simulador.bpmAlvo),
            "activityState": simulador.estadoAtual,
            "activityLabel": simulador.get_nome_estado(),
            "bpmAlert": bool(bpm > 100 or bpm < 50),
            "timestamp": (inicio + timedelta(seconds=i * 3)).strftime("%Y-%m-%d %H:%M:%S"),
            "deviceIndex": idx + 1,
            "timeSinceStart": f"{i * 3}s"
        })

    df = pd.DataFrame(dados)
    df.to_excel(nome_arquivo, sheet_name="Dados Batimentos", index=False)

    print("=" * 60)
    print("MASSA DE BATIMENTOS GERADA")
    print(f"Arquivo: {nome_arquivo}")
    print(f"Registros: {len(df)}")
    print(f"BPM min/max/média: {df.heartRate.min()} / {df.heartRate.max()} / {df.heartRate.mean():.2f}")
    print(f"Alertas: {int(df.bpmAlert.sum())} ({df.bpmAlert.mean()*100:.2f}%)")
    print("=" * 60)
    return df

if __name__ == "__main__":
    gerar_dados_excel(500)
