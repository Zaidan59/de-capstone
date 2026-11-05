"""Example authorized, read-only Zabbix 7 JSON-RPC query.

Never commit a token. Require a scope-approved local environment variable.
Does not run unless operator supplies ZABBIX_API_URL and ZABBIX_API_TOKEN.
"""
import os, json, requests
url = os.environ.get('ZABBIX_API_URL')
token = os.environ.get('ZABBIX_API_TOKEN')
if not url or not token:
    raise SystemExit('Required approved ZABBIX_API_URL and ZABBIX_API_TOKEN are absent.')
payload = {
  'jsonrpc':'2.0','method':'host.get',
  'params':{'output':['hostid','host','name'],'limit':20},
  'id':1,
}
response = requests.post(url,json=payload,headers={
  'Authorization':f'Bearer {token}', 'Content-Type':'application/json-rpc'
},timeout=15)
response.raise_for_status()
content=response.json()
if 'error' in content: raise RuntimeError(content['error'].get('message','Zabbix API error'))
print(json.dumps(content.get('result',[]),indent=2))
