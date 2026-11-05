"""Static checks only. Runtime Docker acceptance is a separate instructor test."""
from pathlib import Path
import json, re, sys, xml.etree.ElementTree as ET
try:
    import yaml
except ImportError:
    raise SystemExit('Install PyYAML to validate Compose YAML: python -m pip install pyyaml')
ROOT = Path(__file__).resolve().parents[1]
required = [
    'compose.yaml', 'compose/openmetadata.yaml', '.env.example',
    'docker/workbench/Dockerfile','docker/airflow/Dockerfile',
    'docker/flink/Dockerfile','docker/spark/Dockerfile',
    'scripts/lab.ps1','scripts/lab.sh','workspace/hop-project/project-config.json',
    'workspace/hop-project/pipelines/pl_load_sales.hpl',
    'workspace/hop-project/workflows/wf_load_sales.hwf',
    'workspace/hop-project/metadata/rdbms/lab-postgres.json',
    'workspace/data/ocs_assets_synthetic.csv',
]
for rel in required:
    assert (ROOT/rel).is_file(),f'Missing {rel}'
base = yaml.safe_load((ROOT/'compose.yaml').read_text())
overlay = yaml.safe_load((ROOT/'compose/openmetadata.yaml').read_text())
assert all(x in base['services'] for x in ('workbench','postgres','mysql','cloudbeaver','airflow','kafka','spark','flink-jobmanager','flink-taskmanager','grafana','superset','keycloak','minio'))
assert 'openmetadata-server' in overlay['services']
for rel in ('config/grafana/provisioning/datasources/postgres.yml',):
    assert yaml.safe_load((ROOT/rel).read_text()) is not None
for f in ROOT.rglob('*.json'):json.loads(f.read_text())
for f in list(ROOT.rglob('*.hpl'))+list(ROOT.rglob('*.hwf')):ET.parse(f)
# Every required Compose secret must appear in the example .env file.
content=(ROOT/'compose.yaml').read_text()+(ROOT/'compose/openmetadata.yaml').read_text()
expected=set(re.findall(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\:\?',content))
actual=set(re.findall(r'^([A-Za-z_][A-Za-z0-9_]*)=',(ROOT/'.env.example').read_text(),flags=re.M))
assert expected <= actual, 'Missing .env keys: '+str(sorted(expected-actual))
for service,info in base['services'].items():
    for p in info.get('ports',[]):
        assert str(p).startswith('127.0.0.1:'),f'{service} publishes a non-localhost port: {p}'
assert not (ROOT/'.env').is_file(),'Do not ship populated .env file'
print('STATIC PACKAGE CHECKS: PASS. This does not validate actual Docker runtime, Hop plugins, or UI.')
