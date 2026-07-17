# T-SQL Sudoku Solver

A deterministic Sudoku solver for Microsoft SQL Server 2019 and newer. The project uses candidate bit masks, set-based eliminations, bounded premise checks, and an independent backtracking validator.

## Main entry point

```sql
DECLARE
    @Solution char(81),
    @Status varchar(32);

EXEC dbo.USP_SudokuSolve
    @Puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @AllowBacktracking = 1,
    @AllowForcing = 1,
    @AllowForcingNets = 0,
    @ReturnSolutionPath = 1,
    @ReturnStatistics = 1;

SELECT @Solution AS Solution, @Status AS Status;
```

`0` represents an empty cell.

## Public procedure parameters

All public procedure, parameter, variable, object, file, and documentation names are maintained in English.

Important solver parameters:

- `@SingleStep`
- `@AllowBacktracking`
- `@AllowForcing`
- `@AllowForcingNets`
- `@ValidateInitialState`
- `@ValidateFinalResult`
- `@MaxIterations`
- `@MaxRuntimeMs`
- `@MaxForcingChecks`
- `@ReturnSolutionPath`
- `@ReturnStatistics`
- `@PrintMessages`
- `@Help`

The exact statuses and result-set contracts are documented in [Public API contract](docs/API_CONTRACT.md).

## Implemented solving families

The procedure executes inexpensive techniques first and restarts after every successful action.

Direct source blocks currently exist for:

- Naked Single and Hidden Single
- Pointing and Claiming
- Naked Pair, Naked Triple, and Naked Quad
- X-Wing, Swordfish, and Jellyfish

The following families are functionally covered by the generalized contradiction-proof stage rather than reconstructed as named geometric patterns:

- Hidden subsets
- finned and sashimi fish
- Skyscraper, Two-String Kite, and Empty Rectangle
- XY-Wing, XYZ-Wing, and W-Wing
- Coloring and Remote Pairs
- X-Chain, XY-Chain, AIC, and Nice Loops
- Grouped AIC
- ALS-XZ and ALS-AIC
- Kraken Fish, Forcing Chains, and bounded Forcing Nets

A generalized deduction removes a candidate only when assuming it true leaves no valid Sudoku completion. This proves the elimination but may report `Generalized Advanced Inference` rather than a shorter human-style pattern name.

The exact implementation mode of every method is available in [Technique coverage](docs/TECHNIQUE_COVERAGE.csv). The logical methods and terminology originate from established Sudoku community references. See [Sources and method provenance](docs/SOURCES.md).

## Diagnostic deduction API

`dbo.USP_SudokuDiagnoseFirstDeduction` returns the first deterministic explicit deduction with candidate masks before and after the action. It accepts either a normal puzzle or a complete 81-row `dbo.SudokuCandidateState` table value for controlled unit tests.

The diagnostic order currently covers:

- Naked Single and Hidden Single
- Pointing and Claiming
- Naked Pair, Naked Triple, and Naked Quad
- X-Wing, Swordfish, and Jellyfish

See [Deduction diagnostic contract](docs/DIAGNOSTIC_CONTRACT.md).

## Installation

Run `sql/00_install.sql` in SQLCMD mode.

The final installation steps normalize local temporary-table constraints, harden the diagnostic definition, and align terminal statuses with the documented API contract.

Optional examples and tests:

```text
sql/02_examples.sql
tests/00_smoke_tests.sql
tests/01_validator_tests.sql
tests/02_contract_tests.sql
tests/03_api_behavior_tests.sql
tests/04_status_boundary_tests.sql
tests/05_direct_set_technique_tests.sql
tests/06_diagnostic_elimination_tests.sql
tests/07_diagnostic_contract_tests.sql
```

Uninstall with `sql/01_uninstall.sql`.

## Design goals

- deterministic result ordering
- candidate masks from `1` through `256`
- one update per target cell and technique
- restart after every successful technique
- bounded expensive checks
- precomputed peer relationships in `dbo.SudokuPeer`
- anonymous local temporary-table constraints in installed procedures
- no permissions granted by installation
- no dependency on CLR or external code
- optional diagnostic result sets

## Validation status

The repository includes static guards, deterministic test scripts, an independent validator, a diagnostic candidate-state API, and a manually triggered SQL Server container workflow. The SQL and prepared tests must still be compiled and executed successfully before production use. See [Continuous integration](docs/CI.md) and [Release checklist](docs/RELEASE_CHECKLIST.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Public API contract](docs/API_CONTRACT.md)
- [Deduction diagnostic contract](docs/DIAGNOSTIC_CONTRACT.md)
- [Technique mapping](docs/TECHNIQUES.md)
- [Technique coverage](docs/TECHNIQUE_COVERAGE.csv)
- [Sources and method provenance](docs/SOURCES.md)
- [Test matrix](docs/TEST_MATRIX.md)
- [Testing](docs/TESTING.md)
- [Continuous integration](docs/CI.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Open work](docs/OPEN_WORK.md)
- [Security and repository data policy](SECURITY.md)

## License

GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
