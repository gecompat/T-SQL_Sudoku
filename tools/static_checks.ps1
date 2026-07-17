$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sqlFiles = Get-ChildItem -Path (Join-Path $repositoryRoot 'sql') -Recurse -File -Filter '*.sql'

$failures = [System.Collections.Generic.List[string]]::new()

$forbiddenPublicNames = @(
    '@NurEinSchritt',
    '@ErlaubeBacktracking',
    '@ErlaubeForcing',
    '@ErlaubeForcingNets',
    '@ValidiereStartzustand',
    '@ValidiereEndergebnis',
    '@MaxIterationen',
    '@MaxLaufzeitMs',
    '@MaxForcingPruefungen',
    '@ResultsetLoesungspfad',
    '@ResultsetStatistik',
    '@PrintMeldungen',
    '@Hilfe'
)

foreach ($file in $sqlFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $relativePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $file.FullName)

    if ($content -match '(?im)^\s*MERGE\s+') {
        $failures.Add("$relativePath contains MERGE.")
    }

    if ($content -match '(?is)CREATE\s+TABLE\s+#\w+.*?CONSTRAINT\s+\[') {
        $failures.Add("$relativePath contains an explicitly named constraint on a local temporary table.")
    }

    foreach ($name in $forbiddenPublicNames) {
        if ($content.Contains($name, [System.StringComparison]::Ordinal)) {
            $failures.Add("$relativePath contains legacy non-English identifier $name.")
        }
    }

    if ($content -match '(?i)RAISERROR\s*\([^\r\n]*\b(?:COALESCE|ISNULL|CONCAT|FORMAT|OBJECT_NAME|DB_NAME)\s*\(') {
        $failures.Add("$relativePath may pass a function directly to RAISERROR.")
    }

    if ($content -match '(?i)EXEC(?:UTE)?\s+[^\r\n]+@[A-Za-z0-9_]+\s*=\s*CASE\b') {
        $failures.Add("$relativePath may pass CASE directly as an EXEC parameter value.")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Static checks passed for $($sqlFiles.Count) SQL files."
