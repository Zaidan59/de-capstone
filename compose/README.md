# Optional OpenMetadata overlay

OpenMetadata 1.12.6 is supplied as an **opt-in experimental integration** because it
has dedicated MySQL/search/bootstrap requirements. The local Compose overlay is
self-contained but has **not been validated on a running Docker Engine**. Check the
OpenMetadata Docker quickstart/release notes before classroom use.

```bash
./scripts/lab.sh up metadata
./scripts/lab.sh preflight metadata
```

```powershell
.\scripts\lab.ps1 up metadata
.\scripts\lab.ps1 preflight metadata
```

Open <http://127.0.0.1:8585>. The overlay uses a separate metadata database,
so it will not overwrite `labdata` or `labsource`. Elasticsearch and the metadata
MySQL database are not published to the host. Ingestion scheduling has been
intentionally disabled in this lightweight profile; registration and manual lineage
can be performed through the UI/API. For scheduled ingestion, use the upstream
OpenMetadata ingestion stack and security configuration as a separate later step.

The repository should not be used as a production OpenMetadata deployment.
