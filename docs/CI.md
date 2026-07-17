# Continuous integration

The repository contains a manual GitHub Actions workflow at `.github/workflows/sql-server-tests.yml`.

## Why the workflow is manual

The SQL has not yet been validated on a live SQL Server instance. The workflow is therefore started with `workflow_dispatch` so that its first runs can be observed and corrected without presenting an unverified green badge.

## Required repository secret

Create a repository Actions secret named:

```text
MSSQL_SA_PASSWORD
```

Use a newly generated value that satisfies SQL Server password complexity requirements. Do not store the value in source files, workflow files, issues, logs, or documentation.

## Workflow stages

1. run PowerShell static checks;
2. start a SQL Server 2022 Linux container;
3. create an isolated `SudokuTest` database;
4. execute installation twice;
5. run smoke tests;
6. run validator tests;
7. uninstall all project objects;
8. reinstall the project.

## First-run expectations

The first execution is a validation exercise, not proof that the project is production-ready. Any compilation, path, container-image, or assertion failure must be corrected and recorded in the release checklist.

## Future matrix

After the SQL Server 2022 workflow is stable, add separate jobs or environments for:

- SQL Server 2019;
- SQL Server 2022;
- SQL Server 2025 when a supported test image is available.
