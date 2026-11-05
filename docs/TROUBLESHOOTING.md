# Troubleshooting (Windows + Linux)

| Symptom | Diagnosis | Action |
| --- | --- | --- |
| Docker Engine unavailable | `docker info` | Start Docker Desktop/Engine; WSL2 backend must be running |
| Long first build | Hop zip, VSCodium repository, apt and Python packages | Use stable internet connection and wait for build completion; cache images before class |
| WSL2 low memory | Docker Desktop resource limits | Stop optional profiles; raise limits if hardware allows |
| 3001 HTTPS certificate warning | Local Webtop self-signed TLS | Verify URL is localhost, accept exception for local lab only |
| Webtop black screen | Desktop/browser caching and shm | Check workbench logs; refresh, use supported Chrome/Firefox, `shm_size: 1gb` |
| Cannot login Workbench | `.env` WEBTOP_USER/PASSWORD | Check exact generated credentials, restart workbench |
| Port conflict | `docker compose ps`, Windows `netstat -ano`, Linux `ss -ltnp` | Change `*_PORT` in .env; preserve `127.0.0.1:` binding |
| CloudBeaver DB timeout | `postgres`/`mysql` health, wrong hostname | Use `postgres:5432` and `mysql:3306` inside CloudBeaver |
| Hop connection missing | project not registered / metadata missing | `hop-setup`; ensure JSON in `hop-project/metadata/rdbms` and environment values |
| PostgreSQL password changed after first boot | Named volume retains original role password | Restore old `.env` or alter database credentials deliberately; `.env` does not rotate volume users automatically |
| Airflow DAG not visible | Airflow init, DAG import errors | Logs `airflow`; verify mounted `modules/airflow/dags` and Airflow 3 imports |
| Kafka cannot connect | Wrong advertised listeners | Containers: `kafka:9092`; host: `localhost:29092` |
| Flink Kafka connector missing | JAR unavailable / classpath mismatch | Check `flink-sql-connector-kafka-3.4.0-1.20.jar` image build |
| Iceberg SQL fails | Spark/Iceberg version mismatch or package JAR | Confirm Spark 3.5.9 Scala2.12 + Iceberg Spark 3.5 runtime and correct catalog config |
| OpenMetadata startup failure | memory/disk, ES bootstrap, version compatibility | Verify ES heap, check `vm.max_map_count`, inspect migration logs; use synthetic PostgreSQL catalog fallback |
| Docker volume cleanup unexpectedly deletes data | `down -v` or `destroy` used | Backup/restores are responsibility of operator; never use on assessed coursework |

On Linux, `docker` group membership is security-sensitive. Windows Docker Desktop
manages its own WSL2 distribution and filesystem; prefer local directories to
OneDrive/network drive for bind-mounted workspaces.
