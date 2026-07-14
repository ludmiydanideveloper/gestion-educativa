import requests
import json

url = "https://qiwwmlysqidwnywmrwko.supabase.co/pg/query"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8"

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json"
}

payload = {
    "query": "SELECT version();"
}

try:
    response = requests.post(url, headers=headers, json=payload)
    print("Status Code:", response.status_code)
    print("Response Text:", response.text)
except Exception as e:
    print("Error:", e)
