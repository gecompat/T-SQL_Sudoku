# Architecture

## Board representation

The board is an 81-character string. `0` means empty. `dbo.SudokuPos` maps each position to row, column, and box.

The working table is `#BoardCells`:

```text
Pos, Row, Col, Box, Digit, CandidateMask
```

Candidate bits:

```text
1→1, 2→2, 3→4, 4→8, 5→16, 6→32, 7→64, 8→128, 9→256
```

`511` means all nine digits are possible.

## Execution model

1. Recalculate candidate masks.
2. Try techniques from cheap to expensive.
3. Apply at most one deterministic logical action.
4. Restart at candidate refresh.
5. Stop when solved, stalled, contradictory, timed out, or iteration-limited.
6. Optionally invoke independent backtracking.

## Generalized engines

### Subset engine

Enumerates combinations of two through four cells or digits inside a house and detects naked or hidden subsets through bit counts.

### Fish engine

Normalizes row- and column-oriented fish into base and cover units. Size controls X-Wing, Swordfish, and Jellyfish. Fin masks extend the same representation to finned and sashimi forms.

### Link graph

A candidate node represents `(Pos, Digit)`. Strong links come from conjugate pairs and bivalue cells. Weak links come from peer candidates and candidates sharing a cell.

Bounded alternating searches support X-Chains, XY-Chains, AICs, Nice Loops, coloring, and grouped links.

### ALS engine

ALS candidates are limited to one through four cells in one house. RCC relationships support ALS-XZ and serve as graph transitions for ALS-AIC.

### Forcing engine

Branches store candidate truth states. `TRUE` propagates through weak links to `FALSE`; `FALSE` propagates through strong links to `TRUE`. Sudoku-specific contradictions are detected. Net depth and branch count are hard-limited.

## Performance controls

- deterministic `TOP (1)` action selection;
- small temporary tables with clustered keys;
- no unbounded recursive CTE;
- bounded chain length, forcing depth, net depth, and branch count;
- expensive methods run only after cheaper methods stall;
- every successful action restarts the loop.
