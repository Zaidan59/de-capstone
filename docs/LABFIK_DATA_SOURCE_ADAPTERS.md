# LABFIK Optional Integration: Zabbix 7 and OCS Inventory 3

This infrastructure intentionally **does not start a duplicate Zabbix or OCS
server** and does not include snapshots of LABFIK production databases.
It provides only sanitized fictional source data and opt-in, read-only adapter
examples. The capstone sponsor/data owner must approve any real connections.

## Zabbix 7

- API endpoint: `https://<approved-zabbix-host>/api_jsonrpc.php`
- Preferred authorization: read-only API token with scoped host groups/items.
- Suggested API methods: `host.get`, `item.get`, `trend.get`, `problem.get`.
- Avoid bulk raw history export without a bounded time range; use hourly trends
  where the data product needs long-term infrastructure utilization.
- Example adapter: `workspace/python/zabbix_readonly_api.py`.

```bash
export ZABBIX_API_URL='https://<approved-host>/api_jsonrpc.php'
export ZABBIX_API_TOKEN='<from an approved local secret source>'
python /config/workspace/python/zabbix_readonly_api.py
```

This example prints host identifiers and names; do **not** submit the raw output
without pseudonymization and permission.

## OCS Inventory 3

Version 3 uses a Django REST API. Do not assume OCS 2.x MySQL table names or
undocumented API paths. Ask the administrator for the actual version, approved
API route, authentication method and query scope.

- `workspace/python/ocs_v3_readonly_api_template.py` is an inert template.
- After approval, set exact `OCS_APPROVED_ENDPOINT` and `OCS_API_TOKEN`.
- The generic bearer-token example may require adapting to the actual OCS
  deployment's authentication and endpoint behavior.
- Prefer approved redacted exports for first-year/student group projects.

## Integration and data contract requirements

- Source owner and allowed fields/host group
- Snapshot/extraction time range and allowed rate
- Primary/source keys, matching rules (IP/hostname alone are insufficient)
- Classification, retention, transfer/storage constraints
- Incremental strategy, reconciliation and error handling
- Access expiry and account deprovisioning after project completion

The two synthetic CSV files in `workspace/data` allow students to design and
validate asset identity crosswalks and governance rules without live access.
