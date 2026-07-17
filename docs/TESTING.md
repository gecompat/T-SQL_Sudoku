# Testing

## Test execution order

Run the installation in SQLCMD mode, then execute the tests in numeric order:

1. `tests/00_smoke_tests.sql`
2. `tests/01_validator_tests.sql`
3. `tests/02_contract_tests.sql`
4. `tests/03_api_behavior_tests.sql`
5. `tests/04_status_boundary_tests.sql`
6. `tests/05_direct_set_technique_tests.sql`

The manual GitHub Actions workflow executes the same sequence, performs a second installation, uninstalls all objects, reinstalls them, and reruns the installation contract test.

## Covered behavior

The current suite prepares assertions for:

- one uniquely solvable puzzle;
- an invalid puzzle;
- a puzzle with at least two solutions;
- deterministic first completion from the validator;
- the public English parameter contract;
- helper-table cardinalities and peer symmetry;
- invalid-argument error numbers;
- `@Help` behavior;
- `SingleStepCompleted`;
- `IterationLimit`;
- natural `LogicStalled` termination;
- `MultipleSolutions`;
- backtracking disabled;
- direct Naked Single and Hidden Single placement.

## Correctness strategy

The logical solver and validator are intentionally separate. The validator uses only Sudoku constraints and backtracking. It can count up to `@MaxSolutions` and therefore distinguishes invalid, unique, and non-unique boards up to the configured bound.

For regression tests, every logical elimination should eventually be checked against all valid completions of the pre-step board. This expensive validation is intended for tests, not normal solving.

## Elimination-technique tests

The current public API returns the solved or partial board, while candidate-only eliminations remain inside `#BoardCells`. Consequently, fully automated positive and negative tests for Pointing, Claiming, Naked Subsets, and Basic Fish require an additional diagnostic contract that exposes the first applied deduction and its before/after candidate masks.

Until that diagnostic surface exists, the coverage file must not mark an elimination method as tested merely because its source block exists.

## Static checks

`tools/static_checks.ps1` verifies the repository source for forbidden legacy identifiers, `MERGE`, unsupported parameter expressions, and temporary-table constraint handling. Static checks do not replace SQL Server compilation and runtime validation.