# Release checklist

A release must not be marked production-ready until every mandatory item is complete.

## Repository and language

- [x] Public procedures, parameters, variables, files, and documentation use English names.
- [x] Repository examples contain only synthetic generic data.
- [x] Method sources and implementation provenance are documented.
- [x] Machine-readable technique coverage is present.
- [x] Technique coverage has been reconciled with the actual source implementation modes.
- [ ] No stale or contradictory implementation claims remain after runtime review.

## Static T-SQL review

- [x] No `MERGE` remains in the helper-table installation.
- [x] Permanent peer relationships are materialized in `dbo.SudokuPeer`.
- [x] Installed procedure definitions contain no explicitly named constraints on local temporary tables.
- [x] Installation fails if temporary-constraint hardening does not remove every known constraint name.
- [x] Contract tests verify the English public parameter names and order.
- [x] Status-contract hardening defines `SingleStepCompleted` and `IterationLimit`.
- [ ] Every variable is declared before use.
- [ ] No `CASE` expression is supplied directly as an `EXEC` parameter assignment.
- [ ] No function call is supplied directly as a `RAISERROR` argument.
- [ ] Recursive CTE column types are explicitly compatible.
- [ ] Every `STRING_AGG` input uses a sufficiently large string type.
- [ ] Case-sensitive object and parameter spelling is consistent.

## Installation

- [ ] Installation succeeds on an empty SQL Server 2019 database.
- [ ] A second installation succeeds without data drift.
- [ ] `dbo.SudokuPos` contains exactly 81 rows.
- [ ] `dbo.SudokuDigitMask` contains exactly 9 rows.
- [ ] `dbo.BitCount511` contains exactly 512 rows.
- [ ] `dbo.SudokuPeer` contains exactly 1,620 directed rows.
- [ ] Every position has exactly 20 peers.
- [ ] Uninstall succeeds.
- [ ] Reinstallation after uninstall succeeds.

## Prepared functional tests

- [x] Smoke test exists.
- [x] Unique, invalid, and multiple-solution validator tests exist.
- [x] Installation contract tests exist.
- [x] API behavior tests exist.
- [x] Single-step, iteration-limit, natural-stall, multiple-solution, and disabled-backtracking tests exist.
- [x] Direct Naked Single and Hidden Single tests exist.
- [x] A diagnostic contract for candidate-only elimination tests is documented.

## Functional validation still required

- [ ] Smoke test passes.
- [ ] Validator tests pass.
- [ ] Installation contract tests pass.
- [ ] API behavior tests pass.
- [ ] Status boundary tests pass.
- [ ] Direct set-technique tests pass.
- [ ] Deterministic timeout test exists and passes.
- [ ] Positive and negative tests exist for every explicit elimination technique.
- [ ] Generalized-proof tests prove both valid eliminations and protected candidates.
- [ ] A complete solution is independently revalidated.

## Performance

- [ ] CPU time measured for easy, hard, and extreme puzzles.
- [ ] Logical reads measured.
- [ ] TempDB allocation measured.
- [ ] Validator state count measured.
- [ ] Parallel execution tested with multiple sessions.
- [ ] `@MaxForcingChecks` scaling documented.
- [ ] SQL Server 2019 tested.
- [ ] SQL Server 2022 tested.
- [ ] SQL Server 2025 tested when available.

## Release

- [ ] All mandatory checklist items are complete.
- [ ] Version number selected.
- [ ] Changelog created.
- [ ] Release notes describe implementation limits honestly.
- [ ] Signed or annotated version tag created.