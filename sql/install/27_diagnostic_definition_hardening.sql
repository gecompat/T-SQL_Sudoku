SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE
    @Definition nvarchar(max),
    @ParameterStart int;

SELECT
    @Definition = ModuleDefinition.[definition]
FROM sys.sql_modules AS ModuleDefinition
WHERE ModuleDefinition.[object_id] =
      OBJECT_ID(N'dbo.USP_SudokuFindFirstDeduction', N'P');

IF @Definition IS NULL
BEGIN
    THROW 50510,
          'Shared deduction engine was not found for definition hardening.',
          1;
END;

/*
    The engine is called from dbo.USP_SudokuSolve, which also owns local temp
    tables named #BoardCells and #Removal. Nested stored procedures can resolve
    a local-temp reference to an outer table with the same name. Use engine-
    specific names so column binding is deterministic and independent of the
    caller's temp-table schema.
*/
SET @Definition = REPLACE(@Definition, N'#BoardCells', N'#EngineBoardCells');
SET @Definition = REPLACE(@Definition, N'#Deduction', N'#EngineDeduction');
SET @Definition = REPLACE(@Definition, N'#Removal', N'#EngineRemoval');

SET @Definition = REPLACE
(
    @Definition,
    N'                AND
                 (
                     (@UnitType IS NULL AND 1 = 1)
                     OR 1 = 1
                 )
                 AND',
    N'                AND'
);

IF CHARINDEX(N'#EngineBoardCells', @Definition) = 0
   OR CHARINDEX(N'#EngineDeduction', @Definition) = 0
   OR CHARINDEX(N'#EngineRemoval', @Definition) = 0
   OR CHARINDEX(N'CREATE TABLE #BoardCells', @Definition) <> 0
   OR CHARINDEX(N'CREATE TABLE #Deduction', @Definition) <> 0
   OR CHARINDEX(N'CREATE TABLE #Removal', @Definition) <> 0
BEGIN
    THROW 50512,
          'Shared deduction engine temp-table names could not be isolated safely.',
          1;
END;

SET @ParameterStart = CHARINDEX(N'(', @Definition);

IF @ParameterStart = 0
BEGIN
    THROW 50511,
          'Shared deduction engine parameter-list marker was not found during hardening.',
          1;
END;

SET @Definition =
    N'ALTER PROCEDURE dbo.USP_SudokuFindFirstDeduction' +
    CHAR(13) + CHAR(10) +
    SUBSTRING(@Definition, @ParameterStart, LEN(@Definition));

EXEC sys.sp_executesql @Definition;
GO
