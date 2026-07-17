# Open work

The repository is a testable release candidate, not a validated production release.

## Static code work

- remove explicitly named constraints from every local temporary table in the large solver and validator modules;
- run `tools/static_checks.ps1` and resolve every finding;
- verify all status values documented in `docs/API_CONTRACT.md` are emitted consistently by the procedure;
- add validator limits and expose whether a solution-count search was truncated.

## Direct technique implementation

The methods marked `Generalized` in `docs/TECHNIQUE_COVERAGE.csv` are proven through candidate contradiction checks rather than reconstructed as named human-style patterns. Direct implementations remain desirable for:

- Hidden Pair, Hidden Triple, Hidden Quad;
- complete Naked Triple and Naked Quad coverage;
- Swordfish and Jellyfish verification;
- finned and sashimi fish;
- Skyscraper, Two-String Kite, Empty Rectangle;
- W-Wing, Coloring, Remote Pairs;
- X-Chain, XY-Chain, AIC and Nice Loops;
- Grouped AIC;
- ALS-XZ and ALS-AIC;
- Kraken Fish;
- explicit branch-based Forcing Chains and Forcing Nets.

Each direct implementation must include positive, boundary, negative, and regression tests before being marked validated.

## Runtime validation

- configure `MSSQL_SA_PASSWORD` as a GitHub Actions secret;
- run the manual SQL Server validation workflow;
- fix compilation and runtime findings;
- validate on SQL Server 2019, 2022, and 2025 when available;
- measure CPU, logical reads, TempDB use, and parallel-session behavior.

## Release condition

Do not create a production release or version 1.0 tag until the mandatory items in `docs/RELEASE_CHECKLIST.md` are complete.
