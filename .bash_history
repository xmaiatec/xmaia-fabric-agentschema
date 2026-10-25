gcloud services enable bigquery.googleapis.com bigqueryconnection.googleapis.com discoveryengine.googleapis.com --project=xmaia-vertex-gmail && bq --location=US mk --dataset --description="Biblioteca Universal de Meta-Schemas" xmaia-vertex-gmail:fabric_global && echo "CONEXAO_E_DATASET_PRONTOS"
bq query --use_legacy_sql=false 'CREATE OR REPLACE TABLE `xmaia-vertex-gmail.fabric_global.agent_fabric_registry` (
  id STRING NOT NULL,
  fabric_pattern_name STRING,
  objective_intent STRING,
  agent_schema_yaml STRING,
  abstract_json_schema STRING,
  bq_target_query STRING,
  duckdb_ddl STRING,
  postgres_ddl STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);' && echo "TABELA_AGENT_FABRIC_CRIADA"
bq query --use_legacy_sql=false 'CREATE OR REPLACE TABLE `xmaia-vertex-gmail.fabric_global.world_schema_catalog` AS
SELECT
  GENERATE_UUID() AS id,
  table_catalog,
  table_schema,
  table_name,
  ARRAY_AGG(STRUCT(column_name, data_type)) AS schema_signature,
  CONCAT("SELECT * FROM `", table_catalog, ".", table_schema, ".", table_name, "` LIMIT 1000") AS instant_bq_query
FROM `bigquery-public-data.github_repos.INFORMATION_SCHEMA.COLUMNS`
GROUP BY table_catalog, table_schema, table_name;' && echo "CATALOGO_MUNDIAL_INDEXADO"
curl -X POST   -H "Authorization: Bearer $(gcloud auth print-access-token)"   -H "Content-Type: application/json"   -H "X-Goog-User-Project: xmaia-vertex-gmail"   "https://discoveryengine.googleapis.com/v1/projects/xmaia-vertex-gmail/locations/global/collections/default_collection/dataStores?dataStoreId=fabric-agentschema-store"   -d '{
    "displayName": "Fabric AgentSchema Engine",
    "industryVertical": "GENERIC",
    "solutionTypes": ["SOLUTION_TYPE_SEARCH"]
  }' && curl -X POST   -H "Authorization: Bearer $(gcloud auth print-access-token)"   -H "Content-Type: application/json"   -H "X-Goog-User-Project: xmaia-vertex-gmail"   "https://discoveryengine.googleapis.com/v1/projects/xmaia-vertex-gmail/locations/global/collections/default_collection/dataStores/fabric-agentschema-store/branches/0/documents:import"   -d '{
    "bigquerySource": {
      "projectId": "xmaia-vertex-gmail",
      "datasetId": "fabric_global",
      "tableId": "world_schema_catalog",
      "dataSchema": "custom"
    },
    "reconciliationMode": "INCREMENTAL"
  }' && echo "MOTOR_GENAI_INDEXANDO"
cat << 'EOF' > ~/fabric_bq_engine.py
import sys, json, subprocess, requests
from google.cloud import bigquery
import google.auth
import google.auth.transport.requests

# 1. Autenticação automática no ambiente Cloud Shell / Local
creds, project = google.auth.default()
creds.refresh(google.auth.transport.requests.Request())
bq_client = bigquery.Client(project="xmaia-vertex-gmail")

FABRIC_SYSTEM_PATTERN = """
# IDENTITY and PURPOSE
You are an Ontology & AgentSchema Compiler (inspired by Daniel Miessler's Fabric and Microsoft AgentSchema).
You NEVER write application boilerplate code. You translate human objectives into:
1. An AgentSchema declarative contract (inputs, outputs, intent).
2. A target BigQuery SQL query over structural schemas.
3. DuckDB and PostgreSQL DDL schemas for instant local materialization.
"""

def resolve_objective_to_schema(user_objective: str):
    # Consulta o índice do GenAI App Builder (Usa os R$ 6.346,94)
    url = (
        "https://discoveryengine.googleapis.com/v1/projects/xmaia-vertex-gmail/"
        "locations/global/collections/default_collection/"
        "dataStores/fabric-agentschema-store/servingConfigs/default_search:search"
    )
    headers = {
        "Authorization": f"Bearer {creds.token}",
        "Content-Type": "application/json",
        "X-Goog-User-Project": "xmaia-vertex-gmail"
    }
    resp = requests.post(url, headers=headers, json={"query": user_objective, "pageSize": 5})
    matches = resp.json().get("results", [])
    print(f"[+] Estruturas mundiais encontradas no motor para o objetivo '{user_objective}': {len(matches)}")
    return matches

if __name__ == "__main__":
    objetivo = sys.argv[1] if len(sys.argv) > 1 else "commits licenses files languages"
    resultados = resolve_objective_to_schema(objetivo)
    print(json.dumps(resultados, indent=2))
EOF

echo "ORQUESTRADOR_CRIADO"
cat << 'EOF' > ~/fabric_bq_engine.py
import sys, json, requests
from google.cloud import bigquery
import google.auth
import google.auth.transport.requests

# 1. Autenticacao automatica no Cloud Shell
creds, project = google.auth.default()
creds.refresh(google.auth.transport.requests.Request())
bq_client = bigquery.Client(project="xmaia-vertex-gmail")

def check_and_search(user_objective: str):
    print("=== 1. VERIFICANDO TABELAS NO BIGQUERY (fabric_global) ===")
    tables = list(bq_client.list_tables("xmaia-vertex-gmail.fabric_global"))
    for t in tables:
        print(f" -> Tabela ativa: {t.table_id}")

    print(f"\n=== 2. CONSULTANDO MOTOR GENAI APP BUILDER (Objetivo: '{user_objective}') ===")
    url = (
        "https://discoveryengine.googleapis.com/v1/projects/xmaia-vertex-gmail/"
        "locations/global/collections/default_collection/"
        "dataStores/fabric-agentschema-store/servingConfigs/default_search:search"
    )
    headers = {
        "Authorization": f"Bearer {creds.token}",
        "Content-Type": "application/json",
        "X-Goog-User-Project": "xmaia-vertex-gmail"
    }
    resp = requests.post(url, headers=headers, json={"query": user_objective, "pageSize": 5})
    data = resp.json()
    matches = data.get("results", [])
    print(f"[+] Status HTTP: {resp.status_code} | Estruturas encontradas: {len(matches)}")
    if matches:
        print(json.dumps(matches, indent=2))
    else:
        print("[!] Resposta bruta do motor (pode ainda estar indexando em background):")
        print(json.dumps(data, indent=2))

if __name__ == "__main__":
    objetivo = sys.argv[1] if len(sys.argv) > 1 else "commits licenses files languages"
    check_and_search(objetivo)
EOF

python3 ~/fabric_bq_engine.py "commits licenses files languages"
cat << 'EOF' > ~/activate_instant_fabric.py
import json, time, requests
from google.cloud import bigquery
import google.auth
import google.auth.transport.requests

creds, _ = google.auth.default()
creds.refresh(google.auth.transport.requests.Request())
bq = bigquery.Client(project="xmaia-vertex-gmail")

HEADERS = {
    "Authorization": f"Bearer {creds.token}",
    "Content-Type": "application/json",
    "X-Goog-User-Project": "xmaia-vertex-gmail"
}
BASE_URL = "https://discoveryengine.googleapis.com/v1/projects/xmaia-vertex-gmail/locations/global/collections/default_collection"

print("=== 1. LENDO SCHEMAS DO BIGQUERY (world_schema_catalog) ===")
rows = list(bq.query("SELECT * FROM `xmaia-vertex-gmail.fabric_global.world_schema_catalog` LIMIT 20").result())
print(f"[+] {len(rows)} estruturas globais carregadas do BigQuery.")

print("\n=== 2. INJETANDO META-SCHEMAS (FABRIC + AGENTSCHEMA) NO DISCOVERY ENGINE ===")
for r in rows:
    cols = [{"name": c["column_name"], "type": c["data_type"]} for c in r.schema_signature]
    col_names = " ".join([c["column_name"] for c in r.schema_signature])
    
    # Monta o DDL instantâneo para DuckDB e PostgreSQL
    ddl_cols = ", ".join([f"{c['column_name']} {c['data_type']}" for c in r.schema_signature])
    duckdb_ddl = f"CREATE TABLE IF NOT EXISTS {r.table_name} ({ddl_cols});"
    
    doc_payload = {
        "id": r.id,
        "jsonData": json.dumps({
            "title": f"Schema: {r.table_catalog}.{r.table_schema}.{r.table_name}",
            "fabric_objective": f"Analyze and query {r.table_name} structure containing: {col_names}",
            "agent_schema": {
                "name": f"agent_{r.table_name}",
                "model": "gemini-2.5-pro",
                "inputs": cols,
                "tools": [{"type": "bigquery", "query": r.instant_bq_query}]
            },
            "instant_bq_query": r.instant_bq_query,
            "duckdb_ddl": duckdb_ddl,
            "columns": cols
        })
    }
    doc_url = f"{BASE_URL}/dataStores/fabric-agentschema-store/branches/0/documents?documentId={r.id}"
    requests.post(doc_url, headers=HEADERS, json=doc_payload)

print("[+] Meta-Schemas indexados! Criando Engine de Busca Semântica...")
engine_payload = {
    "displayName": "Universal Fabric AgentSchema Engine",
    "solutionType": "SOLUTION_TYPE_SEARCH",
    "dataStoreIds": ["fabric-agentschema-store"],
    "searchEngineConfig": {
        "searchTier": "SEARCH_TIER_ENTERPRISE",
        "searchAddOns": ["SEARCH_ADD_ON_LLM"]
    }
}
requests.post(f"{BASE_URL}/engines?engineId=universal-schema-engine", headers=HEADERS, json=engine_payload)

print("\n=== 3. TESTANDO BUSCA DE SCHEMA EM TEMPO REAL ===")
search_url = f"{BASE_URL}/dataStores/fabric-agentschema-store/servingConfigs/default_search:search"
resp = requests.post(search_url, headers=HEADERS, json={"query": "commits repo_name author", "pageSize": 3})
print(json.dumps(resp.json(), indent=2))
EOF

python3 ~/activate_instant_fabric.py
cat << 'EOF' > ~/fix_schema_and_search.py
import json, time, requests
from google.cloud import bigquery
import google.auth
import google.auth.transport.requests

creds, _ = google.auth.default()
creds.refresh(google.auth.transport.requests.Request())
bq = bigquery.Client(project="xmaia-vertex-gmail")

HEADERS = {
    "Authorization": f"Bearer {creds.token}",
    "Content-Type": "application/json",
    "X-Goog-User-Project": "xmaia-vertex-gmail"
}
BASE_URL = "https://discoveryengine.googleapis.com/v1/projects/xmaia-vertex-gmail/locations/global/collections/default_collection"

print("=== 1. ATUALIZANDO SCHEMA DO DATA STORE PARA INDEXACAO TOTAL ===")
schema_url = f"{BASE_URL}/dataStores/fabric-agentschema-store/schemas/default_schema"
schema_payload = {
    "structSchema": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "properties": {
            "title": {"type": "string", "keyPropertyMapping": "title", "retrievable": True, "indexable": True},
            "fabric_objective": {"type": "string", "keyPropertyMapping": "description", "retrievable": True, "indexable": True},
            "table_name": {"type": "string", "retrievable": True, "indexable": True},
            "instant_bq_query": {"type": "string", "retrievable": True, "indexable": True},
            "duckdb_ddl": {"type": "string", "retrievable": True},
            "postgres_ddl": {"type": "string", "retrievable": True},
            "agent_schema_json": {"type": "string", "retrievable": True}
        }
    }
}
r_schema = requests.patch(schema_url, headers=HEADERS, json=schema_payload)
print(f"[+] Status Schema Update: {r_schema.status_code}")

print("\n=== 2. GRAVANDO OS 9 META-SCHEMAS COM STRUCTDATA INDEXAVEL ===")
rows = list(bq.query("SELECT * FROM `xmaia-vertex-gmail.fabric_global.world_schema_catalog`").result())

for r in rows:
    cols = [{"name": c["column_name"], "type": c["data_type"]} for c in r.schema_signature]
    col_names = " ".join([c["column_name"] for c in r.schema_signature])
    ddl_cols = ", ".join([f"{c['column_name']} {c['data_type']}" for c in r.schema_signature])
    
    agent_contract = {
        "name": f"agent_{r.table_name}",
        "intent": f"Query and materialize {r.table_name}",
        "inputs": cols,
        "bq_tool_query": r.instant_bq_query
    }
    
    doc_payload = {
        "id": r.id,
        "structData": {
            "title": f"Meta-Schema: {r.table_catalog}.{r.table_schema}.{r.table_name}",
            "fabric_objective": f"Objective: structure and query {r.table_name} table with fields: {col_names}",
            "table_name": r.table_name,
            "instant_bq_query": r.instant_bq_query,
            "duckdb_ddl": f"CREATE TABLE IF NOT EXISTS {r.table_name} ({ddl_cols});",
            "postgres_ddl": f"CREATE TABLE IF NOT EXISTS {r.table_name} ({ddl_cols});",
            "agent_schema_json": json.dumps(agent_contract)
        }
    }
    doc_url = f"{BASE_URL}/dataStores/fabric-agentschema-store/branches/0/documents/{r.id}"
    res = requests.patch(doc_url, headers=HEADERS, json=doc_payload)
    print(f" -> Schema [{r.table_name}] gravado (HTTP {res.status_code})")

print("\n=== 3. LISTANDO DOCUMENTOS ATIVOS NO MOTOR (PROVA DE CARGA) ===")
list_url = f"{BASE_URL}/dataStores/fabric-agentschema-store/branches/0/documents?pageSize=5"
docs_list = requests.get(list_url, headers=HEADERS).json().get("documents", [])
print(f"[+] Documentos confirmados dentro do Discovery Engine: {len(docs_list)}")
if docs_list:
    print(" -> Exemplo do 1o Meta-Schema pronto no servidor Google:")
    print(json.dumps(docs_list[0].get("structData", {}), indent=2))

print("\n=== 4. TESTANDO BUSCA PELO ENGINE ENTERPRISE (universal-schema-engine) ===")
engine_search_url = f"{BASE_URL}/engines/universal-schema-engine/servingConfigs/default_search:search"
resp = requests.post(engine_search_url, headers=HEADERS, json={"query": "commits repo_name", "pageSize": 3})
print(json.dumps(resp.json(), indent=2))
EOF

python3 ~/fix_schema_and_search.py
cat << 'EOF' > ~/fabric_autonomous_agent.py
import sys, json, uuid, requests
from google.cloud import bigquery
import google.auth
import google.auth.transport.requests

creds, _ = google.auth.default()
creds.refresh(google.auth.transport.requests.Request())
bq = bigquery.Client(project="xmaia-vertex-gmail")

HEADERS = {
    "Authorization": f"Bearer {creds.token}",
    "Content-Type": "application/json",
    "X-Goog-User-Project": "xmaia-vertex-gmail"
}
BASE_URL = "https://discoveryengine.googleapis.com/v1/projects/xmaia-vertex-gmail/locations/global/collections/default_collection"

FABRIC_COMPILER_PREAMBLE = """
You are an autonomous Ontology & Schema Compiler combining Daniel Miessler's Fabric and Microsoft AgentSchema.
Given the user's objective and the retrieved schema context:
1. Extract the pure structural contract (NEVER output application boilerplate code).
2. Return ONLY a valid JSON object (no markdown fences) with these exact keys:
   - "fabric_objective": Clear statement of the analytical/structural goal.
   - "target_table": The best matching table from the catalog.
   - "optimized_bq_sql": A fast, valid BigQuery Standard SQL query (LIMIT 5) that fulfills the objective on that table.
   - "duckdb_ddl": The CREATE TABLE DDL to materialize this query result in local DuckDB.
   - "postgres_ddl": The CREATE TABLE DDL to materialize this query result in local PostgreSQL.
   - "agent_schema": { "name": string, "description": string, "inputs": list, "outputs": list }
"""

def run_autonomous_fabric(objective: str):
    print(f"\n[1/3] Buscando Meta-Schemas e sintetizando Objetivo no GenAI App Builder: '{objective}'...")
    answer_url = f"{BASE_URL}/engines/universal-schema-engine/servingConfigs/default_search:answer"
    
    payload = {
        "query": {"text": objective},
        "searchSpec": {
            "searchParams": {"maxReturnResults": 5}
        },
        "answerGenerationSpec": {
            "modelSpec": {"modelVersion": "stable"},
            "promptSpec": {"preamble": FABRIC_COMPILER_PREAMBLE},
            "includeCitations": False,
            "ignoreAdversarialQuery": True,
            "ignoreNonAnswerSeekingQuery": False
        }
    }
    
    resp = requests.post(answer_url, headers=HEADERS, json=payload).json()
    answer_text = resp.get("answer", {}).get("answerText", "")
    
    # Limpa eventuais blocos markdown se o modelo incluir
    clean_json = answer_text.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
    
    try:
        compiled = json.loads(clean_json)
    except Exception:
        print("[!] Resposta textual do sintetizador:", answer_text)
        return

    print("\n=== [2/3] META-SCHEMA COMPILADO (FABRIC + AGENTSCHEMA) ===")
    print(json.dumps(compiled, indent=2))

    sql = compiled.get("optimized_bq_sql")
    if sql:
        print(f"\n=== [3/3] EXECUTANDO QUERY INSTANTANEA NOS SERVIDORES GOOGLE (BigQuery) ===")
        print(f"SQL Gerado: {sql}\n")
        try:
            rows = [dict(r) for r in bq.query(sql).result()]
            print(f"[+] {len(rows)} registros estruturados retornados em tempo real para alimentar DuckDB/Postgres/Qdrant:")
            print(json.dumps(rows, indent=2, default=str))
        except Exception as e:
            print(f"[!] Aviso na execucao SQL: {e}")

if __name__ == "__main__":
    obj = sys.argv[1] if len(sys.argv) > 1 else "Quero mapear os repositorios mais assistidos com nome do repo e contagem de watches"
    run_autonomous_fabric(obj)
EOF

python3 ~/fabric_autonomous_agent.py "Quero mapear os repositorios mais assistidos com nome do repo e contagem de watches"
cat << 'EOF' > ~/fabric_autonomous_agent.py
import sys, re, json, uuid, requests
from datetime import datetime, timezone
from google.cloud import bigquery
import google.auth
import google.auth.transport.requests

creds, _ = google.auth.default()
creds.refresh(google.auth.transport.requests.Request())
bq = bigquery.Client(project="xmaia-vertex-gmail")

HEADERS = {
    "Authorization": f"Bearer {creds.token}",
    "Content-Type": "application/json",
    "X-Goog-User-Project": "xmaia-vertex-gmail"
}
BASE_URL = "https://discoveryengine.googleapis.com/v1/projects/xmaia-vertex-gmail/locations/global/collections/default_collection"

FABRIC_COMPILER_PREAMBLE = """
You are an autonomous Ontology & Schema Compiler combining Daniel Miessler's Fabric and Microsoft AgentSchema.
Given the user's objective and the retrieved schema context:
1. Extract the pure structural contract (NEVER output application boilerplate code).
2. Return ONLY a valid JSON object (no markdown fences). Never leave empty arrays as blank; always include at least one object in inputs and outputs. Use these exact keys:
   - "fabric_objective": Clear statement of the analytical/structural goal.
   - "target_table": The best matching table from the catalog.
   - "optimized_bq_sql": A fast, valid BigQuery Standard SQL query (LIMIT 5) that fulfills the objective on that table.
   - "duckdb_ddl": The CREATE TABLE DDL to materialize this query result in local DuckDB.
   - "postgres_ddl": The CREATE TABLE DDL to materialize this query result in local PostgreSQL.
   - "agent_schema": { "name": string, "description": string, "inputs": [{"name": "limit", "type": "INT64"}], "outputs": list }
"""

def sanitize_llm_json(raw: str) -> dict:
    clean = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
    start, end = clean.find("{"), clean.rfind("}")
    if start != -1 and end != -1:
        clean = clean[start:end+1]
    # Corrige caso o filtro de citacao remova colchetes vazios []
    clean = re.sub(r':\s*,', ': [],', clean)
    clean = re.sub(r':\s*(\r?\n\s*[}\]])', r': []\1', clean)
    return json.loads(clean)

def run_autonomous_fabric(objective: str):
    print(f"\n=== [1/4] COMPILANDO OBJETIVO NO GENAI APP BUILDER ===\nObjetivo: '{objective}'")
    answer_url = f"{BASE_URL}/engines/universal-schema-engine/servingConfigs/default_search:answer"
    
    payload = {
        "query": {"text": objective},
        "searchSpec": {"searchParams": {"maxReturnResults": 5}},
        "answerGenerationSpec": {
            "modelSpec": {"modelVersion": "stable"},
            "promptSpec": {"preamble": FABRIC_COMPILER_PREAMBLE},
            "includeCitations": False,
            "ignoreAdversarialQuery": True,
            "ignoreNonAnswerSeekingQuery": False
        }
    }
    
    resp = requests.post(answer_url, headers=HEADERS, json=payload).json()
    answer_text = resp.get("answer", {}).get("answerText", "")
    compiled = sanitize_llm_json(answer_text)

    print("\n=== [2/4] META-SCHEMA COMPILADO (FABRIC + AGENTSCHEMA) ===")
    print(json.dumps(compiled, indent=2, ensure_ascii=False))

    # 3. Salva na Biblioteca Universal de Meta-Schemas no BigQuery
    print("\n=== [3/4] REGISTRANDO NA BIBLIOTECA UNIVERSAL (agent_fabric_registry) ===")
    record = {
        "id": str(uuid.uuid4()),
        "fabric_pattern_name": compiled.get("agent_schema", {}).get("name", "custom_pattern"),
        "objective_intent": compiled.get("fabric_objective", objective),
        "agent_schema_yaml": json.dumps(compiled.get("agent_schema", {}), ensure_ascii=False),
        "abstract_json_schema": json.dumps(compiled.get("agent_schema", {}).get("outputs", []), ensure_ascii=False),
        "bq_target_query": compiled.get("optimized_bq_sql", ""),
        "duckdb_ddl": compiled.get("duckdb_ddl", ""),
        "postgres_ddl": compiled.get("postgres_ddl", ""),
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    errors = bq.insert_rows_json("xmaia-vertex-gmail.fabric_global.agent_fabric_registry", [record])
    if not errors:
        print(f"[+] Meta-Schema salvo com sucesso! ID: {record['id']}")
    else:
        print(f"[!] Aviso ao salvar no registro: {errors}")

    # 4. Executa a Query Instantanea nos servidores Google
    sql = compiled.get("optimized_bq_sql")
    if sql:
        print(f"\n=== [4/4] EXECUTANDO QUERY INSTANTANEA NO BIGQUERY ===")
        print(f"SQL: {sql}\n")
        rows = [dict(r) for r in bq.query(sql).result()]
        print(f"[+] {len(rows)} registros retornados em tempo real prontos para DuckDB / Postgres / Qdrant:")
        print(json.dumps(rows, indent=2, default=str, ensure_ascii=False))

if __name__ == "__main__":
    obj = sys.argv[1] if len(sys.argv) > 1 else "Quero mapear os repositorios mais assistidos com nome do repo e contagem de watches"
    run_autonomous_fabric(obj)
EOF

python3 ~/fabric_autonomous_agent.py "Quero mapear os repositorios mais assistidos com nome do repo e contagem de watches"
pip install -q duckdb && cat << 'EOF' > ~/materialize_local_duckdb.py
import duckdb
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

# Executa a query instantanea nos servidores Google e injeta direto no DuckDB
rows = [dict(r) for r in bq.query(meta.bq_target_query).result()]
con.execute("CREATE OR REPLACE TABLE active_objective_data AS SELECT * FROM read_json_auto(?)", [rows])

print("\n[+] Consulta SQL instantanea rodando 100% dentro do seu DuckDB local:")
print(con.execute("SELECT * FROM active_objective_data").fetchall())
print("\n[+] Schema fisico criado no DuckDB:")
print(con.execute("DESCRIBE active_objective_data").fetchall())
EOF

python3 ~/materialize_local_duckdb.py
cat << 'EOF' > ~/materialize_local_duckdb.py
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
EOF

python3 ~/materialize_local_duckd
cat << 'EOF' > ~/materialize_local_duckdb.py
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
EOF

python3 ~/materialize_local_duckdb.py
git init
git add .
git commit -m "feat: initial architecture for Fabric AgentSchema BigQuery bridge"
