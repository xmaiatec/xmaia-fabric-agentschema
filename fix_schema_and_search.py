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
