# T-SQL Sudoku Solver

A deterministic Sudoku solver for Microsoft SQL Server 2019 and newer. The project uses candidate bit masks, set-based eliminations, bounded graph searches, and an independent backtracking validator.

## Main entry point

```sql
DECLARE
    @Solution char(81),
    @Status varchar(32);

EXEC dbo.USP_SudokuSolve
    @Puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @ErlaubeBacktracking = 1,
    @ResultsetLoesungspfad = 1,
    @ResultsetStatistik = 1;

SELECT @Solution AS Solution, @Status AS Status;
```

`0` represents an empty cell.

## Implemented solving families

The procedure executes inexpensive techniques first and restarts after every successful action.

- Singles: Naked Single, Hidden Single
- Locked candidates: Pointing, Claiming
- Subsets: Naked/Hidden Pairs, Triples, Quads
- Basic fish: X-Wing, Swordfish, Jellyfish
- Finned fish engine: Finned/Sashimi X-Wing, Swordfish and Jellyfish
- Single-digit patterns: Skyscraper, Two-String Kite, Empty Rectangle
- Wings: XY-Wing, XYZ-Wing, W-Wing
- Coloring: Simple Coloring, Multi-Coloring, Remote Pairs
- Chains: X-Chain, XY-Chain, AIC, Continuous and Discontinuous Nice Loops
- Grouped inference: Grouped AIC
- Almost Locked Sets: ALS-XZ and ALS-AIC infrastructure
- Last resort inference: Kraken Fish premises, Forcing Chains and bounded Forcing Nets
- Independent bounded backtracking fallback and solution-count validation

Several named patterns are recognized through generalized inference engines rather than duplicated pattern-specific code. For example, Turbot-style patterns, many W-Wings, Nice Loops, and grouped chains are consequences of the AIC graph.

## Installation

Run:

```text
sql/00_install.sql
```

Optional examples and tests:

```text
sql/02_examples.sql
tests/00_smoke_tests.sql
tests/01_validator_tests.sql
```

Uninstall:

```text
sql/01_uninstall.sql
```

## Design goals

- deterministic result ordering
- candidate masks from `1` through `256`
- one update per target cell and technique
- restart after every successful technique
- bounded recursion and bounded forcing branches
- no permissions granted by installation
- no dependency on CLR, JSON, XML, or external code
- diagnostic result sets are optional

## Validation status

The repository includes static guards, deterministic test scripts, and an independent validator. The SQL must still be executed on a SQL Server 2019+ test instance before production use; this repository was assembled without access to a live SQL Server engine.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Technique mapping](docs/TECHNIQUES.md)
- [Testing](docs/TESTING.md)
- [Security and repository data policy](SECURITY.md)

## License

MIT. See [LICENSE](LICENSE).
