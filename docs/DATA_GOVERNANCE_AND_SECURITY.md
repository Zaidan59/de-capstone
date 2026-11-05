# Data Governance and Security Boundaries

1. **Learning use only:** all browser UI ports bind to `127.0.0.1`, not LAN.
   No reverse proxy/public ingress or real production secrets are supplied.
2. **Authorized data:** only simulated datasets ship in this package. Zabbix and
   OCS API examples are inert until data-owner-approved credentials/endpoints
   are provided. Prefer redacted snapshots for student groups.
3. **Least privilege:** use dedicated read-only source users/API tokens with
   limited hosts/items, rate limits, query windows, and metadata scopes.
4. **Credential handling:** `.env` is gitignored; do not commit it or put
   credentials in reports, screenshot URLs, student submissions, or `.hpl` files.
5. **Privacy:** strip/alias host IPs, usernames, employee names, hardware serials,
   and authentication tokens when not needed for an approved analytic purpose.
6. **Retention:** document dataset snapshot date, refresh cadence, retention,
   archive and secure disposal; do not assume indefinite retention is permitted.
7. **Ownership:** capstone groups propose the owner/steward. LABFIK production
   access is decided by the real data owner and institutional policy.
8. **Validation:** scanner output, a dashboard, or a successful SQL result does
   not prove compliance; retain accepted/rejected tests and residual risks.
9. **Network/desktop:** do not expose Webtop to untrusted networks: it provides
   a terminal and elevated rights inside its container. Basic authentication
   over self-signed localhost HTTPS is not adequate for remote Internet access.
10. **Non-production examples:** OpenMetadata overlay, dev Airflow standalone,
    standalone Kafka, embedded Superset SQLite, and Keycloak start-dev are
    suitable only for controlled educational machines.
