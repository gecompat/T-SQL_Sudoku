SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE
    @Definition nvarchar(max),
    @ParameterStart int;

SELECT
    @Definition = ModuleDefinition.[definition]
FROM sys.sql_modules AS ModuleDefinition
WHERE ModuleDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P');

IF @Definition IS NULL
BEGIN
    THROW 50530,
          'The solver was not found for shared-state reset hardening.',
          1;
END;

IF CHARINDEX(N'DECLARE @SharedCandidateState dbo.SudokuCandidateState;', @Definition) = 0
   OR CHARINDEX(N'DECLARE @SharedDeduction TABLE', @Definition) = 0
BEGIN
    THROW 50531,
          'The shared deduction state declarations were not found in the solver.',
          1;
END;

IF CHARINDEX(N'DELETE FROM @SharedCandidateState;', @Definition) = 0
BEGIN
    SET @Definition = REPLACE
    (
        @Definition,
        N'        INSERT INTO @SharedCandidateState',
        N'        DELETE FROM @SharedCandidateState;
        DELETE FROM @SharedDeduction;

        INSERT INTO @SharedCandidateState'
    );
END;

IF CHARINDEX(N'DELETE FROM @SharedCandidateState;', @Definition) = 0
   OR CHARINDEX(N'DELETE FROM @SharedDeduction;', @Definition) = 0
BEGIN
    THROW 50532,
          'The shared deduction state reset could not be applied.',
          1;
END;

SET @ParameterStart = CHARINDEX(N'(', @Definition);

IF @ParameterStart = 0
BEGIN
    THROW 50533,
          'The solver parameter-list marker was not found during shared-state hardening.',
          1;
END;

SET @Definition =
    N'ALTER PROCEDURE dbo.USP_SudokuSolve' +
    CHAR(13) + CHAR(10) +
    SUBSTRING(@Definition, @ParameterStart, LEN(@Definition));

EXEC sys.sp_executesql @Definition;
GO