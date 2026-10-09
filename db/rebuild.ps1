<#
.SYNOPSIS  Rebuild the whole University ERP database from the scripts in db/.
.EXAMPLE   ./db/rebuild.ps1 -Database university_erp -WithTests
.NOTES     Connection: MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PWD (or MYSQL_PASSWORD). WARNING: drops the target database.
#>
param(
  [string]$Database = $(if ($env:MYSQL_DATABASE) { $env:MYSQL_DATABASE } else { 'university_erp' }),
  [switch]$NoSeed, [switch]$NoSample, [switch]$WithTests
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not $env:MYSQL_PWD -and $env:MYSQL_PASSWORD) { $env:MYSQL_PWD = $env:MYSQL_PASSWORD }
$h = if ($env:MYSQL_HOST) { $env:MYSQL_HOST } else { '127.0.0.1' }
$p = if ($env:MYSQL_PORT) { $env:MYSQL_PORT } else { '3306' }
$u = if ($env:MYSQL_USER) { $env:MYSQL_USER } else { 'root' }
$base = @("--host=$h", "--port=$p", "--user=$u", '--default-character-set=utf8mb4')

function Invoke-Sql([string]$Sql, [string]$Db) {
  $a = $base + @(); if ($Db) { $a += "--database=$Db" }
  & mysql @a -e $Sql
  if ($LASTEXITCODE -ne 0) { throw "mysql failed: $Sql" }
}
function Invoke-File([string]$File) { Write-Host "    $File"; Invoke-Sql "source $File" $Database }

Write-Host "==> (re)creating database $Database"
Invoke-Sql "DROP DATABASE IF EXISTS ``$Database``; CREATE DATABASE ``$Database`` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;" $null

Write-Host '==> schema + SQL objects'
'00_admin','01_academics','02_students','03_attendance','04_finance','05_exams','06_placement','07_integration' | ForEach-Object { Invoke-File "$_.sql" }

if (-not $NoSeed) {
  Write-Host '==> seed data'
  Get-Content seed/seed_order.txt | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
    $kind, $path = $_ -split '\s+', 2
    if ($kind -eq 'sample' -and $NoSample) { return }
    Invoke-File $path
  }
}
if ($WithTests) {
  Write-Host '==> tests'
  Get-ChildItem tests -Filter '*.sql' | Sort-Object Name | ForEach-Object { Invoke-File "tests/$($_.Name)" }
  & mysql @($base + @("--database=$Database", '--table')) -e "SELECT module, COUNT(*) AS tests, SUM(outcome='PASS') AS passed, SUM(outcome='FAIL') AS failed FROM test_result GROUP BY module ORDER BY module;"
}
Write-Host "==> done: $Database"
