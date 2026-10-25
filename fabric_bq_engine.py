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
