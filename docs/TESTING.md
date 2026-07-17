# Testing

## Minimum checks

1. Execute `sql/00_install.sql` in an empty test database.
2. Run `tests/00_smoke_tests.sql`.
3. Run `tests/01_validator_tests.sql`.
4. Review all returned statuses and assertions.
5. Capture actual execution plans for hard puzzles when tuning performance.

## Correctness strategy

The logical solver and validator are intentionally separate. The validator uses only Sudoku constraints and backtracking. It can count up to two solutions and therefore distinguishes invalid, unique, and non-unique boards.

For regression tests, verify that every logical elimination is incompatible with every valid completion of the pre-step board. This expensive mode is intended for tests, not normal solving.

## Static checks

The workflow performs repository-level checks only. It verifies required files, disallows tabs and trailing whitespace in SQL, and checks for forbidden placeholder markers. A real SQL Server instance is still required for compile and runtime validation.
