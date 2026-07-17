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
WHERE ModuleDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P');

IF @Definition IS NULL
BEGIN
    THROW 50540,
          'The solver required for header canonicalization was not found.',
          1;
END;

SET @ParameterStart = CHARINDEX(N'(', @Definition);

IF @ParameterStart = 0
BEGIN
    THROW 50541,
          'The solver parameter-list marker was not found.',
          1;
END;

/*
    sys.sql_modules can preserve CREATE PROCEDURE even when the source used
    CREATE OR ALTER. Later installation steps execute the stored definition
    dynamically, so a stable ALTER header is required for repeat installation.
*/
SET @CanonicalDefinition =
    N'ALTER PROCEDURE dbo.USP_SudokuSolve' +
    CHAR(13) + CHAR(10) +
    SUBSTRING(@Definition, @ParameterStart, LEN(@Definition));

EXEC sys.sp_executesql @CanonicalDefinition;
GO

IF OBJECT_ID(N'dbo.USP_SudokuSolve', N'P') IS NULL
BEGIN
    THROW 50542,
          'The solver procedure header could not be canonicalized.',
          1;
END;
GO
