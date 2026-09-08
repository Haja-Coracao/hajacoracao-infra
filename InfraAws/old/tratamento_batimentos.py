from pyspark.sql import SparkSession
from pyspark.sql.functions import col, broadcast, avg, stddev, min, max, count, sum as spark_sum, when, round as spark_round
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType, BooleanType
import pandas as pd
import os

XLSX = "/home/ubuntu/dados_batimentos.xlsx"
CSV = "/home/ubuntu/dados_batimentos.csv"
OUT = "/home/ubuntu/processed_bpm_parquet"

spark = (SparkSession.builder
    .appName("HajaCoracao-BPM-AQE-Otimizado")
    .config("spark.ui.port", "4040")
    .config("spark.sql.adaptive.enabled", "true")
    .config("spark.sql.shuffle.partitions", "6")
    .getOrCreate())
spark.sparkContext.setLogLevel("WARN")

# XLSX -> CSV é apenas adaptação de entrada; o processamento é Spark.
if not os.path.exists(CSV):
    pd.read_excel(XLSX, sheet_name="Dados Batimentos").to_csv(CSV, index=False)

schema = StructType([
    StructField("messageId", IntegerType(), False),
    StructField("deviceId", StringType(), False),
    StructField("heartRate", DoubleType(), False),
    StructField("heartRateTarget", DoubleType(), False),
    StructField("activityState", IntegerType(), False),
    StructField("activityLabel", StringType(), False),
    StructField("bpmAlert", BooleanType(), False),
    StructField("timestamp", StringType(), False),
    StructField("deviceIndex", IntegerType(), False),
    StructField("timeSinceStart", StringType(), False)
])

bpm = spark.read.option("header", True).schema(schema).csv(CSV)

# Otimização manual 1: projection + filtro antes do join.
bpm_filtrado = (bpm
    .select("messageId", "deviceId", "heartRate", "heartRateTarget",
            "activityState", "activityLabel", "bpmAlert", "timestamp")
    .filter(col("heartRate").isNotNull())
    .filter((col("heartRate") >= 30) & (col("heartRate") <= 220))
)

# Dimensão pequena: representa metadados dos 6 dispositivos.
# Broadcast evita shuffle do lado grande.
dim_devices = spark.createDataFrame([
    ("device-01", 1), ("device-02", 2), ("device-03", 3),
    ("device-04", 4), ("device-05", 5), ("device-06", 6)
], ["deviceId", "deviceIndex"]).cache()

bpm_completo = bpm_filtrado.join(
    broadcast(dim_devices),
    on="deviceId",
    how="inner"
)

# Agregação final: esta é wide e pode gerar Exchange.
resultado = (bpm_completo
    .withColumn("timestamp", col("timestamp").cast("timestamp"))
    .groupBy("deviceId", "activityLabel")
    .agg(
        count("*").alias("total_registros"),
        spark_round(avg("heartRate"), 2).alias("media_bpm"),
        spark_round(stddev("heartRate"), 2).alias("desvio_bpm"),
        min("heartRate").alias("min_bpm"),
        max("heartRate").alias("max_bpm"),
        spark_sum(when(col("bpmAlert") == True, 1).otherwise(0)).alias("alertas")
    )
)

print("\n=== PLANO FÍSICO OTIMIZADO ===")
resultado.explain("formatted")
print("\n=== CODEGEN ===")
resultado.explain("codegen")

resultado.orderBy("alertas", ascending=False).show(20, truncate=False)

# Ação e persistência do resultado tratado.
resultado.write.mode("overwrite").parquet(OUT)
print(f"\nDados tratados salvos em: {OUT}")
print("Spark UI: http://localhost:4040")
print("AQE:", spark.conf.get("spark.sql.adaptive.enabled"))

# Mantém a SparkSession viva para que a Spark UI continue disponível na EC2.
# Para encerrar depois da análise: Ctrl+C no processo ou `pkill -f tratamento_batimentos.py`.
import time
print("Sessão Spark mantida ativa para inspeção da Spark UI.")
while True:
    time.sleep(3600)
