-- Capstone Group A03 Infrastructure Baseline (idempotent)
-- Adds the `curated` schema and least-privilege RBAC roles (`etl_writer`, `tpid_analyst`)
-- specified in docs/01_Capstone_Proposal_GROUP A03.docx.

CREATE SCHEMA IF NOT EXISTS curated;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'etl_writer') THEN
    CREATE ROLE etl_writer NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tpid_analyst') THEN
    CREATE ROLE tpid_analyst NOLOGIN;
  END IF;
END
$$;

-- Allow labuser to assume roles via `SET ROLE` during testing without hardcoded passwords.
GRANT etl_writer, tpid_analyst TO labuser;

-- etl_writer: read/write across ingestion, staging, quality, ops, and analytical schemas.
GRANT USAGE, CREATE ON SCHEMA raw, stg, dq, ops, mart, mdm, curated, semantic TO etl_writer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA raw, stg, dq, ops, mart, mdm, curated, semantic TO etl_writer;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA raw, stg, dq, ops, mart, mdm, curated, semantic TO etl_writer;

ALTER DEFAULT PRIVILEGES FOR ROLE labuser IN SCHEMA raw, stg, dq, ops, mart, mdm, curated, semantic
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO etl_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE labuser IN SCHEMA raw, stg, dq, ops, mart, mdm, curated, semantic
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO etl_writer;

-- tpid_analyst: strict read-only access limited to curated mart and semantic views.
REVOKE ALL ON SCHEMA raw, stg, dq, ops, mdm FROM tpid_analyst;
GRANT USAGE ON SCHEMA curated, semantic TO tpid_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA curated, semantic TO tpid_analyst;

ALTER DEFAULT PRIVILEGES FOR ROLE labuser IN SCHEMA curated, semantic
  GRANT SELECT ON TABLES TO tpid_analyst;
ALTER DEFAULT PRIVILEGES FOR ROLE etl_writer IN SCHEMA curated, semantic
  GRANT SELECT ON TABLES TO tpid_analyst;
