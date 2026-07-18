SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    Local temporary tables are created in tempdb. Explicitly named constraints
    on local temporary tables can collide when multiple sessions compile or
    execute the same procedure concurrently.
*/
DECLARE
    @ObjectName sysname,
    @Definition nvarchar(max),
    @OriginalDefinition nvarchar(max),
    @ParameterStart int,
    @AlterHeader nvarchar(300);

DECLARE ProcedureCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT ProcedureName
FROM
(
    VALUES
        (CONVERT(sysname, N'dbo.USP_SudokuValidate')),
        (CONVERT(sysname, N'dbo.USP_SudokuSolve'))
) AS Procedures(ProcedureName);

OPEN ProcedureCursor;

FETCH NEXT FROM ProcedureCursor
INTO @ObjectName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT
        @Definition = ModuleDefinition.[definition]
    FROM sys.sql_modules AS ModuleDefinition
    WHERE ModuleDefinition.[object_id] = OBJECT_ID(@ObjectName, N'P');

    IF @Definition IS NULL
    BEGIN
        CLOSE ProcedureCursor;
        DEALLOCATE ProcedureCursor;

        THROW 50400,
              'A procedure required for temporary-constraint hardening was not found.',
              1;
    END;

    SET @OriginalDefinition = @Definition;

    SET @Definition = REPLACE(@Definition, N'CONSTRAINT [PK_Stack] ', N'');
    SET @Definition = REPLACE(@Definition, N'CONSTRAINT [PK_SearchStack] ', N'');
    SET @Definition = REPLACE(@Definition, N'CONSTRAINT [PK_BoardCells] ', N'');
    SET @Definition = REPLACE(@Definition, N'CONSTRAINT [PK_TechniqueLog] ', N'');
    SET @Definition = REPLACE(@Definition, N'CONSTRAINT [PK_Removal] ', N'');

    IF @Definition <> @OriginalDefinition
    BEGIN
        SET @ParameterStart = CHARINDEX(N'(', @Definition);

        IF @ParameterStart = 0
        BEGIN
            CLOSE ProcedureCursor;
            DEALLOCATE ProcedureCursor;

            THROW 50402,
                  'A procedure parameter-list marker was not found during temporary-constraint hardening.',
                  1;
        END;

        SET @AlterHeader = N'ALTER PROCEDURE ' + @ObjectName;
        SET @Definition =
            @AlterHeader + CHAR(13) + CHAR(10) +
            SUBSTRING(@Definition, @ParameterStart, LEN(@Definition));

        EXEC sys.sp_executesql @Definition;
    END;

    FETCH NEXT FROM ProcedureCursor
    INTO @ObjectName;
END;

CLOSE ProcedureCursor;
DEALLOCATE ProcedureCursor;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.sql_modules AS ModuleDefinition
    WHERE ModuleDefinition.[object_id] IN
          (
              OBJECT_ID(N'dbo.USP_SudokuValidate', N'P'),
              OBJECT_ID(N'dbo.USP_SudokuSolve', N'P')
          )
      AND
      (
          CHARINDEX(N'CONSTRAINT [PK_Stack]', ModuleDefinition.[definition]) > 0
          OR CHARINDEX(N'CONSTRAINT [PK_SearchStack]', ModuleDefinition.[definition]) > 0
          OR CHARINDEX(N'CONSTRAINT [PK_BoardCells]', ModuleDefinition.[definition]) > 0
          OR CHARINDEX(N'CONSTRAINT [PK_TechniqueLog]', ModuleDefinition.[definition]) > 0
          OR CHARINDEX(N'CONSTRAINT [PK_Removal]', ModuleDefinition.[definition]) > 0
      )
)
BEGIN
    THROW 50401,
          'Named constraints remain on local temporary tables after hardening.',
          1;
END;
GO