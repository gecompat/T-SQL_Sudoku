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

## Implemented solving families

The procedure executes inexpensive techniques first and restarts after every successful action.

- Singles: Naked Single, Hidden Single
- Locked candidates: Pointing, Claiming
- Subsets: Naked/Hidden Pairs, Triples, Quads
- Basic fish: X-Wing, Swordfish, Jellyfish
- Finned and sashimi fish
- Single-digit patterns: Skyscraper, Two-String Kite, Empty Rectangle
- Wings: XY-Wing, XYZ-Wing, W-Wing
- Coloring: Simple Coloring, Multi-Coloring, Remote Pairs
- Chains: X-Chain, XY-Chain, AIC, Continuous and Discontinuous Nice Loops
- Grouped inference: Grouped AIC
- Almost Locked Sets: ALS-XZ and ALS-AIC
- Kraken Fish, Forcing Chains, and bounded Forcing Nets
- Independent backtracking fallback and solution-count validation

The inexpensive techniques are detected directly. More advanced named methods are functionally covered by the generalized contradiction-proof stage: a candidate is removed only when assuming that candidate true leaves no valid Sudoku completion. This produces a complete logical proof, although the solution-path row may report `Generalized Advanced Inference` rather than a specific geometric pattern name.

The logical methods and terminology originate from established Sudoku community references. See [Sources and method provenance](docs/SOURCES.md) for a method-by-method attribution and the distinction between external logical rules and this repository's original T-SQL implementation.

## Installation

Run `sql/00_install.sql` in SQLCMD mode.

Optional examples and tests:

```text
sql/02_examples.sql
tests/00_smoke_tests.sql
tests/01_validator_tests.sql
```

Uninstall with `sql/01_uninstall.sql`.

## Design goals

- deterministic result ordering
- candidate masks from `1` through `256`
- one update per target cell and technique
- restart after every successful technique
- bounded expensive checks
- no permissions granted by installation
- no dependency on CLR or external code
- optional diagnostic result sets

## Validation status

The repository includes static guards, deterministic test scripts, and an independent validator. The SQL must still be compiled and executed on a SQL Server 2019+ test instance before production use; the repository was assembled without access to a live SQL Server engine.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Technique mapping](docs/TECHNIQUES.md)
- [Sources and method provenance](docs/SOURCES.md)
- [Testing](docs/TESTING.md)
- [Security and repository data policy](SECURITY.md)

## License

GNU Affero General Public License v3.0. See [LICENSE](LICENSE).