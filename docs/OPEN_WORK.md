# Open work

The repository is a testable release candidate, not a validated production release.

## Completed without a live SQL Server

- helper-table installation no longer uses `MERGE`;
- permanent peer relationships are materialized in `dbo.SudokuPeer`;
- installation normalizes the created procedures so local temporary-table constraints are anonymous;
- the installed solver distinguishes `SingleStepCompleted`, `IterationLimit`, `LogicStalled`, and `MultipleSolutions`;
- `tests/02_contract_tests.sql` verifies helper data, English public parameters, and installed procedure definitions;
- `tests/03_api_behavior_tests.sql` verifies documented input errors, invalid-board status, and Help behavior;
- `tests/04_status_boundary_tests.sql` prepares assertions for single-step, iteration limit, natural stall, multiple solutions, and disabled backtracking;
- `tests/05_direct_set_technique_tests.sql` prepares direct Naked Single and Hidden Single tests;
- `dbo.SudokuCandidateState` and `dbo.USP_SudokuDiagnoseFirstDeduction` provide a deterministic candidate-state diagnostic surface;
- `tests/06_diagnostic_elimination_tests.sql` prepares positive and negative tests for Pointing, Claiming, Naked Pair, and X-Wing;
- `tests/07_diagnostic_contract_tests.sql` validates the diagnostic type, wrapper, parameters, errors, and Help behavior;
- `dbo.USP_SudokuFindFirstDeduction` is the shared explicit-deduction engine used by both the solver and diagnostic wrapper;
- the solver installation removes its duplicated explicit-technique block and replaces it with one call to the shared engine;
- candidate refresh now intersects current masks with legal masks, preserving earlier logical eliminations;
- `tests/08_shared_engine_contract_tests.sql` verifies solver integration, wrapper integration, refresh preservation, and result equivalence;
- the validator test suite includes unique, invalid, and multiple-solution puzzles;
- `tools/static_checks.ps1` verifies that every known source constraint is covered by the mandatory hardening step;
- technique coverage was reconciled with the actual solver source: XY-Wing, XYZ-Wing, hidden subsets, and ALS-XZ remain generalized rather than direct implementations.

## Static and contract work still open

- run `tools/static_checks.ps1` in a checked-out repository and resolve any environmental findings;
- compile the shared engine, rewritten solver, diagnostic wrapper, and all tests on SQL Server;
- execute all prepared status, contract, shared-engine, and technique tests;
- verify that the dynamic source markers used by `26_shared_deduction_engine.sql` match SQL Server module text exactly;
- add positive, boundary, negative, and regression cases for Naked Triple, Naked Quad, Swordfish, and Jellyfish;
- add a bounded validator state count, runtime limit, and truncation output;
- add a deterministic timeout test after runtime behavior is measured on SQL Server.

## Direct technique implementation

The methods marked `Generalized` in `docs/TECHNIQUE_COVERAGE.csv` are proven through candidate contradiction checks rather than reconstructed as named human-style patterns. Direct implementations remain desirable for:

- Hidden Pair, Hidden Triple, Hidden Quad;
- finned and sashimi fish;
- Skyscraper, Two-String Kite, Empty Rectangle;
- XY-Wing, XYZ-Wing, W-Wing;
- Coloring and Remote Pairs;
- X-Chain, XY-Chain, AIC and Nice Loops;
- Grouped AIC;
- ALS-XZ and ALS-AIC;
- Kraken Fish;
- explicit branch-based Forcing Chains and Forcing Nets.

## Runtime validation

- configure `MSSQL_SA_PASSWORD` as a GitHub Actions secret;
- run the manual SQL Server validation workflow;
- fix compilation and runtime findings;
- validate on SQL Server 2019, 2022, and 2025 when available;
- measure CPU, logical reads, TempDB use, and parallel-session behavior.

## Release condition

Do not create a production release or version 1.0 tag until the mandatory items in `docs/RELEASE_CHECKLIST.md` are complete.