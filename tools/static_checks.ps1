$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sqlRoot = Join-Path $repositoryRoot 'sql'
$sqlFiles = Get-ChildItem -Path $sqlRoot -Recurse -File -Filter '*.sql'

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

$hardeningPath = Join-Path $sqlRoot 'install/30_temp_constraint_hardening.sql'
$installerPath = Join-Path $sqlRoot '00_install.sql'
$hardeningContent = if (Test-Path -LiteralPath $hardeningPath) {
    Get-Content -LiteralPath $hardeningPath -Raw
}
else {
    ''
}
$installerContent = if (Test-Path -LiteralPath $installerPath) {
    Get-Content -LiteralPath $installerPath -Raw
}
else {
    ''
}

$allowedSourceConstraintNames = @(
    'PK_Stack',
    'PK_BoardCells',
    'PK_TechniqueLog',
    'PK_Removal'
)

function Get-NamedLocalTempConstraints {
    param(
        [Parameter(Mandatory)]
        [string[]] $Lines
    )

    $results = [System.Collections.Generic.List[string]]::new()
    $insideLocalTempTable = $false

    foreach ($line in $Lines) {
        if (-not $insideLocalTempTable) {
            if ($line -match '(?i)^\s*CREATE\s+TABLE\s+#\w+') {
                $insideLocalTempTable = $true
            }
            else {
                continue
            }
        }

        $constraintMatch = [regex]::Match(
            $line,
            '(?i)\bCONSTRAINT\s+\[(?<Name>[^\]]+)\]'
        )

        if ($constraintMatch.Success) {
            $results.Add($constraintMatch.Groups['Name'].Value)
        }

        if ($line -match '^\s*\);\s*(?:--.*)?$') {
            $insideLocalTempTable = $false
        }
    }

    return $results
}

foreach ($file in $sqlFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $lines = Get-Content -LiteralPath $file.FullName
    $relativePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\', '/')

    if ($content -match '(?im)^\s*MERGE\s+') {
        $failures.Add("$relativePath contains MERGE.")
    }

    $namedTempConstraints = Get-NamedLocalTempConstraints -Lines $lines

    foreach ($constraintName in $namedTempConstraints) {
        $isKnownProcedureSource = $relativePath -in @(
            'sql/install/10_USP_SudokuValidate.sql',
            'sql/install/20_USP_SudokuSolve.sql'
        )
        $isKnownConstraint = $constraintName -in $allowedSourceConstraintNames
        $hardeningContainsReplacement =
            $hardeningContent.Contains("CONSTRAINT [$constraintName] ", [System.StringComparison]::Ordinal)
        $installerIncludesHardening =
            $installerContent.Contains('install/30_temp_constraint_hardening.sql', [System.StringComparison]::Ordinal)

        if (-not ($isKnownProcedureSource -and $isKnownConstraint -and $hardeningContainsReplacement -and $installerIncludesHardening)) {
            $failures.Add("$relativePath contains explicitly named local-temp constraint $constraintName without verified installation hardening.")
        }
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

if (-not (Test-Path -LiteralPath $hardeningPath)) {
    $failures.Add('sql/install/30_temp_constraint_hardening.sql is missing.')
}

if (-not $installerContent.Contains('install/30_temp_constraint_hardening.sql', [System.StringComparison]::Ordinal)) {
    $failures.Add('sql/00_install.sql does not include temporary-constraint hardening.')
}

foreach ($constraintName in $allowedSourceConstraintNames) {
    if (-not $hardeningContent.Contains("CONSTRAINT [$constraintName] ", [System.StringComparison]::Ordinal)) {
        $failures.Add("Temporary-constraint hardening does not cover $constraintName.")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Static checks passed for $($sqlFiles.Count) SQL files."
