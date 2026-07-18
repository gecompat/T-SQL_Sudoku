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