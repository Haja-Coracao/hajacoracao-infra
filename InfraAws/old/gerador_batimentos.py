import pandas as pd
import random
from datetime import datetime, timedelta
import time

# ──────────────────────────────────────────────────────────────
# SIMULADOR DE BATIMENTO CARDÍACO
# ──────────────────────────────────────────────────────────────

class HeartRateSimulator:
    def __init__(self):
        self.estadoAtual = 0
        self.contador = 0
        self.bpmAtual = 75
        self.bpmAlvo = 75
        self.nomes_estados = ['Descanso', 'Aquecimento', 'Corrida leve', 'Intensidade','Sprint']
    
    def resetar_batimento(self):
        self.estadoAtual = 0
        self.contador = 0
        self.bpmAtual = 75
        self.bpmAlvo = 75
    
    def gerar_alvo(self):
        estado = self.estadoAtual
        rand = lambda min_val, max_val: random.randint(min_val, max_val)
        
        if estado == 0:
            return rand(60, 89)
        elif estado == 1:
            return rand(90, 110)
        elif estado == 1:
            return rand(110, 139)
        elif estado == 2:
            return rand(140, 164)
        elif estado == 3:
            return rand(165, 190)
        return 75
    
    def atualizar_estado(self):
        chance = random.randint(0, 99)
        estado = self.estadoAtual
        
        if estado == 0:
            if chance < 30:
                self.estadoAtual += 1
        elif estado == 1:
            if chance < 20:
                self.estadoAtual -= 1
            elif chance >= 70:
                self.estadoAtual += 1
        elif estado == 2:
            if chance < 25:
                self.estadoAtual -= 1
            elif chance >= 75:
                self.estadoAtual += 1
        elif estado == 3:
            if chance < 40:
                self.estadoAtual -= 1
    
    def ajustar_gradualmente(self):
        passo = 3
        if self.bpmAtual < self.bpmAlvo:
            self.bpmAtual = min(self.bpmAtual + passo, self.bpmAlvo)
        elif self.bpmAtual > self.bpmAlvo:
            self.bpmAtual = max(self.bpmAtual - passo, self.bpmAlvo)
    
    def gerar_batimento(self):
        self.contador += 1
        
        # A cada 3 chamadas: reavalia estado e define novo alvo
        if self.contador % 3 == 0:
            self.atualizar_estado()
            self.bpmAlvo = self.gerar_alvo()
        
        self.ajustar_gradualmente()
        return self.bpmAtual
    
    def get_nome_estado(self):
        return self.nomes_estados[self.estadoAtual] if self.estadoAtual < len(self.nomes_estados) else 'Desconhecido'

# ──────────────────────────────────────────────────────────────
# DISPOSITIVOS IOT
# ──────────────────────────────────────────────────────────────

devices = [
    {'id': 'alexandre-04241043', 'connectionString': 'HostName=grupo4.azure-devices.net;DeviceId=alexandre-04241043;SharedAccessKey=2aTpA14ZxxGLPPfMgz3H03EhSh4ZAD7gQ7ONoTeWhl0='},
    {'id': 'sampaio-04241023', 'connectionString': 'HostName=grupo4.azure-devices.net;DeviceId=sampaio-04241023;SharedAccessKey=CqnnwWyLfyThIY3fzpGaqGxGgTEAWpOU0R3l/2qB0Gg='},
    {'id': 'roque-04241033', 'connectionString': 'HostName=grupo4.azure-devices.net;DeviceId=roque-04241033;SharedAccessKey=2N73fN6iesnnHBXW/8hEmlZ+/2CisVq7OBSeiJglYMQ='},
    {'id': 'leandro-04241025', 'connectionString': 'HostName=grupo4.azure-devices.net;DeviceId=leandro-04241025;SharedAccessKey=1bFq0AxRNfwUZUEVB/S1bEqpLSnniJwVbmcM//23bDM='},
    {'id': 'presilli-04241056', 'connectionString': 'HostName=grupo4.azure-devices.net;DeviceId=presilli-04241056;SharedAccessKey=X5Gvt1S03gs3GZDZx4MZNqaQ5MID4TBW04jzf1u393Q='},
    {'id': 'diego-04241019', 'connectionString': 'HostName=grupo4.azure-devices.net;DeviceId=diego-04241019;SharedAccessKey=jhyef8zb5qOkzqxWEkIfXxCaNBWtp2iz3SL5G8Xz7jw='}
]

# ──────────────────────────────────────────────────────────────
# GERADOR DE DADOS
# ──────────────────────────────────────────────────────────────

def gerar_dados_excel(num_registros=500):
    """
    Gera um DataFrame com dados simulados de batimentos cardíacos
    e salva em um arquivo Excel
    """
    
    print(f"\n{'='*65}")
    print(f"GERANDO {num_registros} REGISTROS DE BATIMENTOS CARDÍACOS")
    print(f"{'='*65}\n")
    
    # Inicializa o simulador
    simulador = HeartRateSimulator()
    simulador.resetar_batimento()
    
    # Lista para armazenar os dados
    dados = []
    
    # Tempo inicial
    tempo_inicial = datetime.now() - timedelta(hours=num_registros // 60)
    
    # Gera os registros
    for i in range(num_registros):
        # Seleciona um dispositivo (alternando entre eles)
        dispositivo_idx = i % len(devices)
        dispositivo = devices[dispositivo_idx]
        
        # Gera o BPM
        bpm = simulador.gerar_batimento()
        estado = simulador.get_nome_estado()
        
        # Verifica alerta
        bpm_alert = bpm > 100 or bpm < 50
        
        # Timestamp
        timestamp = tempo_inicial + timedelta(seconds=i * 3)  # 3 segundos entre cada registro
        
        # Adiciona registro
        registro = {
            'messageId': i + 1,
            'deviceId': dispositivo['id'],
            'heartRate': bpm,
            'heartRateTarget': simulador.bpmAlvo,
            'activityState': simulador.estadoAtual,
            'activityLabel': estado,
            'bpmAlert': bpm_alert,
            'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            # Dados adicionais para análise
            'deviceIndex': dispositivo_idx + 1,
            'timeSinceStart': f"{i * 3}s"
        }
        
        dados.append(registro)
        
        # Progresso
        if (i + 1) % 100 == 0:
            print(f"Gerados {i + 1} registros...")
    
    # Cria DataFrame
    df = pd.DataFrame(dados)
    
    # Estatísticas básicas
    print(f"\n{'='*65}")
    print("ESTATÍSTICAS DOS DADOS GERADOS")
    print(f"{'='*65}")
    print(f"Total de registros: {len(df)}")
    print(f"Período: {df['timestamp'].min()} até {df['timestamp'].max()}")
    print(f"\nDistribuição por dispositivo:")
    print(df['deviceId'].value_counts().to_string())
    print(f"\nEstatísticas de BPM:")
    print(f"  Mínimo: {df['heartRate'].min()}")
    print(f"  Máximo: {df['heartRate'].max()}")
    print(f"  Média: {df['heartRate'].mean():.2f}")
    print(f"  Mediana: {df['heartRate'].median()}")
    print(f"\nDistribuição por estado:")
    print(df['activityLabel'].value_counts().to_string())
    print(f"\nAlertas de BPM: {df['bpmAlert'].sum()} registros")
    print(f"  Porcentagem de alertas: {(df['bpmAlert'].sum() / len(df) * 100):.2f}%")
    
    # Salva em Excel
    nome_arquivo = f'dados_batimentos_{datetime.now().strftime("%Y%m%d_%H%M%S")}.xlsx'
    
    with pd.ExcelWriter(nome_arquivo, engine='openpyxl') as writer:
        # Planilha principal com todos os dados
        df.to_excel(writer, sheet_name='Dados Batimentos', index=False)
        
        # Planilha com estatísticas
        estatisticas = {
            'Métrica': ['Total Registros', 'BPM Mínimo', 'BPM Máximo', 'BPM Médio', 'BPM Mediana', 
                       'Alertas BPM', '% Alertas'],
            'Valor': [len(df), df['heartRate'].min(), df['heartRate'].max(), 
                     round(df['heartRate'].mean(), 2), df['heartRate'].median(),
                     df['bpmAlert'].sum(), f"{(df['bpmAlert'].sum() / len(df) * 100):.2f}%"]
        }
        df_estatisticas = pd.DataFrame(estatisticas)
        df_estatisticas.to_excel(writer, sheet_name='Estatísticas', index=False)
        
        # Resumo por dispositivo
        resumo_dispositivo = df.groupby('deviceId').agg({
            'heartRate': ['count', 'mean', 'min', 'max'],
            'bpmAlert': 'sum'
        }).round(2)
        resumo_dispositivo.columns = ['Total', 'Média BPM', 'Mín BPM', 'Máx BPM', 'Alertas']
        resumo_dispositivo.to_excel(writer, sheet_name='Resumo por Dispositivo')
    
    print(f"\n{'='*65}")
    print(f"✅ ARQUIVO SALVO: {nome_arquivo}")
    print(f"{'='*65}")
    
    return df, nome_arquivo

# ──────────────────────────────────────────────────────────────
# EXECUÇÃO PRINCIPAL
# ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("""
===================================================================
       GERADOR DE DADOS - BATIMENTO CARDÍACO
===================================================================

Dispositivos configurados: 6
   - alexandre-04241043
   - sampaio-04241023
   - roque-04241033
   - leandro-04241025
   - presilli-04241056
   - diego-04241019  

Estados do batimento:
   Estado 0 → Descanso              (60-89 bpm)
   Estado 1 → Aquecimento           (90-109 bpm)
   Estado 2 → Corrida leve          (110-139 bpm)
   Estado 3 → Intensidade           (140-164 bpm)
   Estado 4 → Sprint                (165-189 bpm)


===================================================================
""")
    
    # Gera 500 registros (pode aumentar para mais)
    df, arquivo = gerar_dados_excel(num_registros=500)
    
    # Mostra os primeiros registros
    print("\nPRIMEIROS 10 REGISTROS:")
    print(df[['messageId', 'deviceId', 'heartRate', 'activityLabel', 'bpmAlert']].head(10).to_string())
    
    # Exemplo de como usar os dados
    print("\nEXEMPLO DE FILTRO - Dados de alerta:")
    alertas = df[df['bpmAlert'] == True]
    print(f"Encontrados {len(alertas)} registros com alerta")
    if len(alertas) > 0:
        print(alertas[['timestamp', 'deviceId', 'heartRate', 'activityLabel']].head(5).to_string())