:setvar RootPath "."

:r $(RootPath)/install/00_tables.sql
:r $(RootPath)/install/05_technique_mode_corrections.sql
:r $(RootPath)/install/07_diagnostic_types.sql
:r $(RootPath)/install/10_USP_SudokuValidate.sql
:r $(RootPath)/install/20_USP_SudokuSolve.sql
:r $(RootPath)/install/25_USP_SudokuDiagnoseFirstDeduction.sql
:r $(RootPath)/install/27_diagnostic_definition_hardening.sql
:r $(RootPath)/install/30_temp_constraint_hardening.sql
:r $(RootPath)/install/35_status_contract_hardening.sql

PRINT 'T-SQL Sudoku installation completed.';
GO
