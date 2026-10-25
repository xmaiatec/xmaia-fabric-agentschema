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
