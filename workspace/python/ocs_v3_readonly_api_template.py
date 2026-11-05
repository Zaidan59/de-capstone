"""OCS Inventory 3 API discovery template; no endpoint/schema assumptions.

OCS Inventory 3 REST endpoints vary by deployment/configuration. Set an exact
approved read-only full URL after consulting the local OCS administrator.
Never store or export hardware serials/addresses without data owner approval.
"""
import os, requests
url = os.environ.get('OCS_APPROVED_ENDPOINT')
token = os.environ.get('OCS_API_TOKEN')
if not url or not token:
    raise SystemExit('Obtain approved OCS_APPROVED_ENDPOINT and OCS_API_TOKEN first')
resp = requests.get(url,headers={'Authorization':f'Bearer {token}'},timeout=15)
resp.raise_for_status()
print('HTTP',resp.status_code,'content-type',resp.headers.get('content-type','unknown'))
print('Do not print raw asset inventory until redaction/classification is approved.')
