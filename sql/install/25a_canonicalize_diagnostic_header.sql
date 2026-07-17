SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE
    @Definition nvarchar(max),
    @ParameterStart int,
    @CanonicalDefinition nvarchar(max);

SELECT
    @Definition = ModuleDefinition.[definition]
FROM sys.sql_modules AS ModuleDefinition
WHERE ModuleDefinition.[object_id] =
      OBJECT_ID(N'dbo.USP_SudokuDiagnoseFirstDeduction', N'P');

IF @Definition IS NULL
BEGIN
    THROW 50518,
          'The diagnostic procedure required for header canonicalization was not found.',
          1;
END;

SET @ParameterStart = CHARINDEX(N'(', @Definition);

IF @ParameterStart = 0
BEGIN
    THROW 50519,
          'The diagnostic procedure parameter-list marker was not found.',
          1;
END;

SET @CanonicalDefinition =
    N'CREATE OR ALTER PROCEDURE dbo.USP_SudokuDiagnoseFirstDeduction' +
    CHAR(13) + CHAR(10) +
    SUBSTRING(@Definition, @ParameterStart, LEN(@Definition));

EXEC sys.sp_executesql @CanonicalDefinition;
GO

IF OBJECT_ID(N'dbo.USP_SudokuDiagnoseFirstDeduction', N'P') IS NULL
BEGIN
    THROW 50517,
          'The diagnostic procedure header could not be canonicalized.',
          1;
END;
GO
