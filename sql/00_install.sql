:setvar RootPath "."

:r $(RootPath)\install\00_tables.sql
:r $(RootPath)\install\05_technique_mode_corrections.sql
:r $(RootPath)\install\10_USP_SudokuValidate.sql
:r $(RootPath)\install\20_USP_SudokuSolve.sql

PRINT 'T-SQL Sudoku installation completed.';
GO
