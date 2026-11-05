# Apache Hop starter project

This example does not require any files from earlier class assignments.

1. Open Hop GUI (`hop-gui`) in the Workbench browser desktop.
2. Register project `capstone-local`, using this directory as its home.
3. Create an environment called `docker-local`.
4. Create a relational database connection named **lab-postgres**:
   - Type PostgreSQL, host `postgres`, port `5432`
   - DB `labdata`, user `labuser`, password from `.env` (`POSTGRES_PASSWORD`)
5. Store connection metadata in this project (and do not commit plaintext
   passwords; use an environment variable or a secret management workflow).
6. Open `pipelines/pl_load_sales.hpl` and review the Table Input / Table
   Output mapping. This example **truncates** `stg.sales_orders` before loading;
   use only on the synthetic, disposable local sample.
7. Run `workflows/wf_load_sales.hwf` from the GUI, then verify 60 rows.

If the metadata connection was not yet created, the sample pipeline will
properly report a missing `lab-postgres` connection. The first-run exercise
is to create this connection in Hop GUI.

For real capstone cases, replace the synthetic source and build incremental,
validated, recoverable pipelines; do not query production Zabbix/OCS until
read-only scope and data owner approval are documented.
