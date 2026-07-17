SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @Definition nvarchar(max);

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

IF @Definition NOT LIKE N'%DECLARE @SharedCandidateState dbo.SudokuCandidateState;%'
   OR @Definition NOT LIKE N'%DECLARE @SharedDeduction TABLE%'
BEGIN
    THROW 50531,
          'The shared deduction state declarations were not found in the solver.',
          1;
END;

IF @Definition NOT LIKE N'%DELETE FROM @SharedCandidateState;%'
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

IF @Definition NOT LIKE N'%DELETE FROM @SharedCandidateState;%'
   OR @Definition NOT LIKE N'%DELETE FROM @SharedDeduction;%'
BEGIN
    THROW 50532,
          'The shared deduction state reset could not be applied.',
          1;
END;

EXEC sys.sp_executesql @Definition;
GO