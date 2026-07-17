# Public API contract

## `dbo.USP_SudokuSolve`

### Output parameters

- `@Solution char(81) OUTPUT`: complete or partial board, depending on status.
- `@Status varchar(32) OUTPUT`: terminal solver status.

### Status values

| Status | Meaning | `@Solution` |
|---|---|---|
| `SolvedLogically` | Completed without search fallback | Complete |
| `SolvedByBacktracking` | Completed by independent search fallback | Complete |
| `LogicStalled` | Enabled logical stages made no further progress | Partial |
| `MultipleSolutions` | At least two valid completions were found | First completion returned |
| `Invalid` | Initial puzzle violates Sudoku constraints or has no completion | Original or partial board |
| `Contradiction` | Current candidate state became inconsistent | Partial |
| `Timeout` | `@MaxRuntimeMs` was reached | Partial |
| `IterationLimit` | `@MaxIterations` was reached | Partial |
| `SingleStepCompleted` | `@SingleStep = 1` and one action was applied | Partial or complete |

A normal terminal status is returned through `@Status`. Invalid procedure arguments and internal invariant violations raise an error with `THROW`.

### Primary result set

| Column | Type | Meaning |
|---|---|---|
| `Board` | `char(81)` | Complete or partial board |
| `Status` | `varchar(32)` | Terminal status |
| `Iterations` | `int` | Solver loop iterations |
| `ElapsedMilliseconds` | `bigint` | Wall-clock duration |

### Solution-path result set

Returned when `@ReturnSolutionPath = 1`.

| Column | Meaning |
|---|---|
| `StepNo` | Deterministic action sequence |
| `IterationNo` | Solver loop iteration |
| `TechniqueName` | Explicit method or generalized proof stage |
| `ActionType` | `Set` or `Eliminate` |
| `Pos` | Position from 1 through 81 |
| `Digit` | Assigned digit when applicable |
| `OldCandidateMask` | Candidate mask before the action |
| `NewCandidateMask` | Candidate mask after the action |
| `RemovedMask` | Removed candidates |
| `ElapsedMicroseconds` | Technique duration |
| `Details` | Human-readable explanation |
| `BoardBefore` | Board before the action |
| `BoardAfter` | Board after the action |

### Statistics result set

Returned when `@ReturnStatistics = 1`. It aggregates execution count, successful changes, affected cells, and elapsed time by technique.

## `dbo.USP_SudokuValidate`

The validator counts solutions independently from the human-style solver.

- `@SolutionCount`: number of solutions found up to `@MaxSolutions`.
- `@FirstSolution`: deterministic first completion.
- A count equal to `@MaxSolutions` means at least that many solutions exist; it does not prove that there are no additional solutions.
