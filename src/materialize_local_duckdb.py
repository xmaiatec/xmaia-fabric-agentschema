import re, duckdb
from google.cloud import bigquery

bq = bigquery.Client(project="xmaia-vertex-gmail")

print("=== 1. BUSCANDO ULTIMO META-SCHEMA DA SUA BIBLIOTECA UNIVERSAL ===")
query_registry = """
SELECT id, fabric_pattern_name, objective_intent, bq_target_query, duckdb_ddl
FROM `xmaia-vertex-gmail.fabric_global.agent_fabric_registry`
ORDER BY created_at DESC LIMIT 1
"""
meta = list(bq.query(query_registry).result())[0]
print(f"[+] Meta-Schema carregado: {meta.fabric_pattern_name} (ID: {meta.id})")
print(f"[+] Objetivo: {meta.objective_intent}")
print(f"[+] DDL DuckDB: {meta.duckdb_ddl}")

print("\n=== 2. MATERIALIZANDO ESTRUTURA E DADOS INSTANTANEAMENTE NO DUCKDB LOCAL ===")
con = duckdb.connect("xmaia_local_fabric.duckdb")

# 1. Executa o proprio DDL compilado pelo Meta-Schema para criar a estrutura fisica
con.execute(meta.duckdb_ddl)

# Descobre o nome da tabela recem-criada pelo DDL
m = re.search(r"TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+([a-zA-Z0-9_.]+)", meta.duckdb_ddl, re.I)
table_name = m.group(1) if m else "active_objective_data"
con.execute(f"DELETE FROM {table_name}")

# 2. Busca os dados em tempo real nos servidores Google e injeta em memoria no DuckDB
rows = list(bq.query(meta.bq_target_query).result())
if rows:
    placeholders = ", ".join(["?"] * len(rows[0]))
    tuples = [tuple(r.values()) for r in rows]
    con.executemany(f"INSERT INTO {table_name} VALUES ({placeholders})", tuples)

print(f"\n[+] Schema fisico criado no DuckDB (Tabela: {table_name}):")
for col in con.execute(f"DESCRIBE {table_name}").fetchall():
    print(f" -> Coluna: {col[0]} | Tipo: {col[1]}")

print(f"\n[+] Consulta SQL instantanea rodando 100% dentro do seu DuckDB local ({table_name}):")
for row in con.execute(f"SELECT * FROM {table_name}").fetchall():
    print(f" -> {row}")
