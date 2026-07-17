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
    'PK_SearchStack',
    'PK_BoardCells',
    'PK_TechniqueLog',
    'PK_Removal'
)

# Marker-based hardening files intentionally contain old and new T-SQL blocks as
# string literals. Lexical checks must run against source modules, not those
# generated patch strings, otherwise valid patch text is reported as live code.
$sourceModulePaths = @(
    'sql/install/00_tables.sql',
    'sql/install/05_technique_mode_corrections.sql',
    'sql/install/07_diagnostic_types.sql',
    'sql/install/10_USP_SudokuValidate.sql',
    'sql/install/20_USP_SudokuSolve.sql',
    'sql/install/25_USP_SudokuDiagnoseFirstDeduction.sql',
    'sql/01_uninstall.sql',
    'sql/02_examples.sql'
)

$procedureSourcePaths = @(
    'sql/install/10_USP_SudokuValidate.sql',
    'sql/install/20_USP_SudokuSolve.sql',
    'sql/install/25_USP_SudokuDiagnoseFirstDeduction.sql'
)

foreach ($file in $sqlFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $relativePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\', '/')

    if ($relativePath -notin $sourceModulePaths) {
        continue
    }

    if ($content -match '(?im)^\s*MERGE\s+') {
        $failures.Add("$relativePath contains MERGE.")
    }

    if ($relativePath -in $procedureSourcePaths) {
        $lines = Get-Content -LiteralPath $file.FullName
        $insideTempTable = $false
        $parenthesisDepth = 0

        foreach ($line in $lines) {
            if (-not $insideTempTable -and $line -match '(?i)^\s*CREATE\s+TABLE\s+#\w+') {
                $insideTempTable = $true
                $parenthesisDepth = 0
            }

            if ($insideTempTable) {
                $parenthesisDepth += ([regex]::Matches($line, '\(')).Count
                $parenthesisDepth -= ([regex]::Matches($line, '\)')).Count

                if ($line -match '(?i)CONSTRAINT\s+\[(?<Name>[^\]]+)\]') {
                    $constraintName = $Matches['Name']
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

                if ($parenthesisDepth -le 0 -and $line -match ';\s*$') {
                    $insideTempTable = $false
                }
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
    Write-Host 'Static check failures:'
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Static checks passed for $($sourceModulePaths.Count) source SQL files."