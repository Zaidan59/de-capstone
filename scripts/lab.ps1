# Windows PowerShell 5.1+ / PowerShell 7, no Git Bash or Python on host required.
param(
  [Parameter(Position=0)][string]$Command = 'help',
  [Parameter(Position=1)][string]$Module = 'core'
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $Root
try {
  function Get-Secret {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buf = New-Object byte[] 24
    $rng.GetBytes($buf)
    $rng.Dispose()
    return ([BitConverter]::ToString($buf)).Replace('-','').ToLowerInvariant()
  }
  function Compose([string[]]$Parameters, [bool]$Metadata = $false) {
    $all = @('compose','-f','compose.yaml')
    if ($Metadata) { $all += @('-f','compose/openmetadata.yaml') }
    $all += $Parameters
    & docker @all
    if ($LASTEXITCODE -ne 0) { throw "docker compose failed ($LASTEXITCODE): $($Parameters -join ' ')" }
  }
  function Ensure-Ready {
    if (-not (Test-Path .env)) { throw 'Missing .env; run .\scripts\lab.ps1 init' }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker Engine is not running' }
  }
  function Get-Services([string]$mod) {
    switch ($mod) {
      'core' {@('postgres','mysql','workbench','cloudbeaver')}
      {$_ -in 'orchestration','m08'} {@('airflow')}
      {$_ -in 'streaming','m09'} {@('kafka','flink-jobmanager','flink-taskmanager')}
      {$_ -in 'lakehouse','m10'} {@('spark')}
      'objectstore' {@('minio')}
      {$_ -in 'observability','m13'} {@('grafana')}
      {$_ -in 'bi','m14'} {@('superset')}
      'identity' {@('keycloak')}
      {$_ -in 'metadata','m11'} {@('openmetadata-server')}
      default { throw "Unknown module $mod" }
    }
  }
  switch ($Command.ToLowerInvariant()) {
    'init' {
      if (Test-Path .env) { throw 'Refusing to overwrite existing .env' }
      $lines = Get-Content -LiteralPath .env.example
      $new = foreach ($line in $lines) {
        if ($line -match '^([^#][^=]*)=__GENERATE__$') { "$($Matches[1])=$(Get-Secret)" }
        else { $line }
      }
      [System.IO.File]::WriteAllLines((Join-Path $Root '.env'), [string[]]$new,
        (New-Object System.Text.UTF8Encoding($false)))
      Write-Host 'Created .env with generated local-only passwords.'
    }
    {$_ -in 'up','start'} {
      Ensure-Ready
      $core = Get-Services 'core'
      if ($Module -eq 'core') { Compose (@('up','-d','--build')+$core) }
      else {
        Compose (@('up','-d')+$core)
        if ($Module -in @('metadata','m11')) {
          Compose @('--profile','metadata','up','-d','openmetadata-server') $true
        } else {
          $profile = switch ($Module) {
            m08 {'orchestration'} m09 {'streaming'} m10 {'lakehouse'}
            m13 {'observability'} m14 {'bi'} default {$Module}
          }
          Compose (@('--profile',$profile,'up','-d','--build')+(Get-Services $Module))
        }
      }
    }
    'stop' {
      Ensure-Ready
      if ($Module -in @('metadata','m11')) { Compose @('--profile','metadata','stop','openmetadata-server','openmetadata-search','openmetadata-db') $true }
      else { Compose (@('stop')+(Get-Services $Module)) }
    }
    {$_ -in 'ps','status'} {
      Ensure-Ready
      Compose @('ps','-a')
      if ($Module -eq 'metadata') { Compose @('--profile','metadata','ps','-a') $true }
    }
    'preflight' {
      Ensure-Ready
      Compose @('ps')
      Compose @('exec','-T','postgres','psql','-U','labuser','-d','labdata','-Atc','SELECT COUNT(*) FROM raw.sales_orders;')
      Compose @('exec','-T','mysql','sh','-lc','MYSQL_PWD="$MYSQL_PASSWORD" mysql -u "$MYSQL_USER" -D "$MYSQL_DATABASE" -N -e "SELECT COUNT(*) FROM demo_orders;"')
      Compose @('exec','-T','workbench','bash','-lc','python --version && java -version && codium --version | head -n 1 && test -f /opt/hop/hop-gui.sh')
      Write-Host 'Desktop https://localhost:3001 (self-signed); CloudBeaver http://localhost:8978'
    }
    'hop-setup' { Ensure-Ready; Compose @('exec','-T','-u','abc','workbench','/usr/local/bin/hop-setup') }
    'hop-demo' {
      Ensure-Ready
      Compose @('exec','-T','-u','abc','workbench','/usr/local/bin/hop-setup')
      Compose @('exec','-T','-u','abc','workbench','bash','-lc','cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local -r local -f /config/workspace/hop-project/workflows/wf_load_sales.hwf')
      Compose @('exec','-T','postgres','psql','-U','labuser','-d','labdata','-Atc','SELECT COUNT(*) FROM stg.sales_orders;')
    }
    'seed' { Ensure-Ready; Compose @('exec','-T','postgres','psql','-U','labuser','-d','labdata','-f','/docker-entrypoint-initdb.d/02-demo.sql') }
    'seed-food' { Ensure-Ready; Compose @('exec','-T','-u','abc','workbench','python','/config/workspace/python/load_food_to_mysql.py') }
    'reset-demo' {
      Ensure-Ready
      Compose @('exec','-T','postgres','psql','-U','labuser','-d','labdata','-c','TRUNCATE stg.sales_orders, mart.daily_sales;')
      Compose @('exec','-T','postgres','psql','-U','labuser','-d','labdata','-f','/docker-entrypoint-initdb.d/02-demo.sql')
    }
    'backup' {
      Ensure-Ready
      New-Item -ItemType Directory -Path backups -Force | Out-Null
      $file = Join-Path $Root ("backups/labdata_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.sql')
      $lines = & docker compose -f compose.yaml exec -T postgres pg_dump -U labuser -d labdata --no-owner --no-privileges
      if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL dump failed' }
      [System.IO.File]::WriteAllLines($file, [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))
      Write-Host "Saved $file"
    }
    'logs' { Ensure-Ready; Compose @('logs','--tail=120',$Module) }
    'shell' { Ensure-Ready; Compose @('exec','-u','abc','workbench','bash') }
    'config' {
      Ensure-Ready
      if ($Module -eq 'metadata') { Compose @('--profile','metadata','config','--quiet') $true }
      else { Compose @('config','--quiet') }
    }
    'destroy' {
      Ensure-Ready
      $confirm = Read-Host 'Type DELETE to remove containers and ALL named volumes'
      if ($confirm -ne 'DELETE') { throw 'Cancelled' }
      Compose @('--profile','metadata','down','--volumes','--remove-orphans') $true
    }
    default {
      Write-Host 'Data Engineering Capstone Lab - Windows PowerShell'
      Write-Host '.\scripts\lab.ps1 init'
      Write-Host '.\scripts\lab.ps1 up core'
      Write-Host '.\scripts\lab.ps1 up orchestration|streaming|lakehouse|metadata|observability|bi|identity|objectstore'
      Write-Host '.\scripts\lab.ps1 preflight / hop-setup / hop-demo / status / backup / reset-demo'
      Write-Host '.\scripts\lab.ps1 stop streaming / logs <service> / destroy'
    }
  }
} finally { Pop-Location }
