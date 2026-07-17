# Deduction diagnostic contract

## Purpose

Candidate-only eliminations do not change the 81-character board string. Automated tests therefore need a stable diagnostic surface that exposes the first applied deduction without relying on message text or internal temporary tables.

## Proposed output

A future diagnostic entry point should return exactly one row for the first applied logical action:

| Column | Type | Meaning |
|---|---|---|
| `TechniqueName` | `varchar(64)` | Direct method or generalized proof stage |
| `ActionType` | `varchar(16)` | `Set` or `Eliminate` |
| `Position` | `tinyint` | Target position from 1 through 81 |
| `Digit` | `tinyint` | Assigned or removed digit |
| `OldCandidateMask` | `smallint` | Candidate mask before the action |
| `NewCandidateMask` | `smallint` | Candidate mask after the action |
| `RemovedMask` | `smallint` | Aggregate removed candidates |
| `EvidenceType` | `varchar(32)` | Cell, house, fish, chain, ALS, or premise proof |
| `Evidence` | `nvarchar(2000)` | Deterministic structured description |
| `BoardBefore` | `char(81)` | Board before the action |
| `BoardAfter` | `char(81)` | Board after the action |

## Required semantics

- One call analyzes one board state and returns at most one action.
- The same board and parameters must return the same action.
- A `Set` action must change exactly one board position.
- An `Eliminate` action must change at least one candidate mask and must not change the board string.
- `RemovedMask` must equal `OldCandidateMask & ~NewCandidateMask` for a single target.
- Evidence must use stable position numbers and English technique names.
- No diagnostic call may persist puzzle data.

## Test use

Once implemented, each explicit elimination technique must have:

1. a positive case that returns the expected technique and target;
2. a boundary case that returns the same valid deduction under minimal premises;
3. a negative case that returns no deduction for an almost-matching pattern;
4. a regression case for every corrected defect.

## Implementation options

Preferred: factor first-step detection into a shared internal procedure used by both `dbo.USP_SudokuSolve` and a public diagnostic wrapper.

Avoid duplicating technique SQL in a test-only procedure, because duplicated detection logic can pass tests while the production solver remains incorrect.