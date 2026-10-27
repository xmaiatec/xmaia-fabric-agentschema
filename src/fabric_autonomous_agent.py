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
