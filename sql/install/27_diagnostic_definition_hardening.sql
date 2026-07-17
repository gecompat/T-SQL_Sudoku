SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @Definition nvarchar(max);

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

EXEC sys.sp_executesql @Definition;
GO