# Deduction diagnostic contract

## Purpose

Candidate-only eliminations do not change the 81-character board string. Automated tests therefore use `dbo.USP_SudokuDiagnoseFirstDeduction` to expose the first deterministic explicit deduction without relying on message text or internal temporary tables.

## Inputs

```sql
DECLARE @CandidateState dbo.SudokuCandidateState;

EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = @Puzzle,
    @CandidateState = @CandidateState,
    @UseCandidateState = 0,
    @Help = 0;
```

`@UseCandidateState = 0` derives candidates from `@Puzzle`.

`@UseCandidateState = 1` requires exactly 81 rows in `@CandidateState`, with one candidate mask from 1 through 511 for each position. This mode exists for deterministic unit tests of candidate patterns.

## Result set

The procedure returns zero or more target rows belonging to one first logical action. A set action returns one row. An elimination action may return multiple target rows when one pattern removes candidates from several cells.

| Column | Type | Meaning |
|---|---|---|
| `SequenceNo` | `int` | Deterministic target-row order |
| `TechniqueName` | `varchar(64)` | Directly detected method |
| `ActionType` | `varchar(16)` | `Set` or `Eliminate` |
| `Pos` | `tinyint` | Target position from 1 through 81 |
| `Digit` | `tinyint` | Assigned digit for a set action |
| `OldCandidateMask` | `smallint` | Candidate mask before the action |
| `NewCandidateMask` | `smallint` | Candidate mask after the action |
| `RemovedMask` | `smallint` | Candidates removed from this target |
| `Evidence` | `nvarchar(2000)` | Stable English explanation |

## Implemented diagnostic order

1. Naked Single
2. Hidden Single
3. Pointing
4. Claiming
5. Naked Pair
6. Naked Triple
7. Naked Quad
8. X-Wing
9. Swordfish
10. Jellyfish

The first applicable technique wins. All target rows for that first action are returned in position order.

## Required semantics

- The same state and parameters must return the same action.
- A `Set` action returns exactly one target row.
- An `Eliminate` action returns at least one target row.
- `RemovedMask` equals `OldCandidateMask & ~NewCandidateMask`.
- All names and evidence are English.
- No diagnostic call persists puzzle or candidate data.
- Invalid puzzle input raises error `50500`.
- Invalid candidate-state input raises error `50501`.

## Test coverage

`tests/06_diagnostic_elimination_tests.sql` contains prepared positive and negative candidate-state tests for:

- Pointing;
- Claiming;
- Naked Pair;
- X-Wing.

`tests/07_diagnostic_contract_tests.sql` validates the type, procedure, parameter order, errors, and Help behavior.

## Remaining architectural work

The diagnostic procedure currently mirrors the explicit deduction order used by the solver. The preferred final architecture is a shared internal first-deduction engine called by both `dbo.USP_SudokuSolve` and `dbo.USP_SudokuDiagnoseFirstDeduction`. Until that refactoring is complete, tests must compare diagnostic behavior with solver solution-path behavior on a live SQL Server instance.
