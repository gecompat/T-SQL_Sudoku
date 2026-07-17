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
2. Try inexpensive explicit techniques first.
3. Apply at most one deterministic action.
4. Restart at candidate refresh after every action.
5. Run generalized advanced inference only after the inexpensive techniques stall.
6. Stop when solved, stalled, contradictory, timed out, or iteration-limited.
7. Optionally invoke the independent backtracking fallback.

## Explicit engines

### Singles

Naked Singles and Hidden Singles place one digit at a time.

### Locked candidates

Pointing and Claiming remove candidates across box and row or column intersections.

### Naked subset engine

A bounded recursive combination search detects Naked Pairs, Triples, and Quads. Hidden subsets are functionally covered by the generalized inference stage.

### Basic fish engine

Row- and column-oriented candidates are normalized into base and cover units. Fish size controls X-Wing, Swordfish, and Jellyfish.

## Generalized advanced inference

For each selected candidate, the solver creates a candidate-true premise and calls the independent validator. When that premise has no valid completion, the candidate is logically false and is removed.

This complete contradiction proof functionally covers advanced named families such as:

- Hidden Pairs, Triples, and Quads
- finned and sashimi fish
- Skyscraper, Two-String Kite, and Empty Rectangle
- XY-Wing, XYZ-Wing, and W-Wing deductions not found earlier
- Simple Coloring, Multi-Coloring, and Remote Pairs
- X-Chains, XY-Chains, AICs, and Nice Loops
- Grouped AIC
- ALS-XZ and ALS-AIC
- Kraken Fish and Forcing Chains

When `@AllowForcingNets = 1`, all alternative candidates of a cell may also be tested. A candidate is placed when every alternative premise has no valid completion.

The proof is complete, but the solution-path result reports the generalized engine rather than reconstructing a specific geometric pattern name.

## Independent validator

`dbo.USP_SudokuValidate` uses only Sudoku constraints and a minimum-remaining-values backtracking search. It does not call the logical solver. This separation prevents circular validation.

## Performance controls

- deterministic `TOP (1)` action selection
- bounded subset and fish sizes
- `@MaxForcingChecks` limits expensive premise tests per iteration
- `@MaxRuntimeMs` and `@MaxIterations` provide hard limits
- expensive inference runs only after cheaper methods stall
- every successful action restarts the loop
