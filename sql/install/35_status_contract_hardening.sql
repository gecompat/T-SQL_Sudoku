SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE
    @Definition nvarchar(max),
    @OldBlock nvarchar(max),
    @NewBlock nvarchar(max),
    @ParameterStart int;

SELECT
    @Definition = ModuleDefinition.[definition]
FROM sys.sql_modules AS ModuleDefinition
WHERE ModuleDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P');

IF @Definition IS NULL
BEGIN
    THROW 50410,
          'dbo.USP_SudokuSolve was not found for status-contract hardening.',
          1;
END;

SET @OldBlock = N'    IF @Status = ''Initialized''
    BEGIN
        IF @Solution NOT LIKE ''%0%''
            SET @Status = ''SolvedLogically'';
        ELSE
            SET @Status = ''LogicStalled'';
    END;';

SET @NewBlock = N'    IF @Status = ''Initialized''
    BEGIN
        IF @Solution NOT LIKE ''%0%''
            SET @Status = ''SolvedLogically'';
        ELSE IF @SingleStep = 1
                AND EXISTS (SELECT 1 FROM #TechniqueLog)
            SET @Status = ''SingleStepCompleted'';
        ELSE IF @IterationNumber >= @MaxIterations
            SET @Status = ''IterationLimit'';
        ELSE
            SET @Status = ''LogicStalled'';
    END;';

IF CHARINDEX(N'SingleStepCompleted', @Definition) = 0
BEGIN
    IF CHARINDEX(@OldBlock, @Definition) = 0
    BEGIN
        THROW 50411,
              'The expected solver status block was not found.',
              1;
    END;

    SET @Definition = REPLACE(@Definition, @OldBlock, @NewBlock);
END;

SET @ParameterStart = CHARINDEX(N'(', @Definition);

IF @ParameterStart = 0
BEGIN
    THROW 50413,
          'The solver parameter-list marker was not found during status hardening.',
          1;
END;

SET @Definition =
    N'ALTER PROCEDURE dbo.USP_SudokuSolve' +
    CHAR(13) + CHAR(10) +
    SUBSTRING(@Definition, @ParameterStart, LEN(@Definition));

EXEC sys.sp_executesql @Definition;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.sql_modules AS ModuleDefinition
    WHERE ModuleDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P')
      AND CHARINDEX(N'SingleStepCompleted', ModuleDefinition.[definition]) > 0
      AND CHARINDEX(N'IterationLimit', ModuleDefinition.[definition]) > 0
)
BEGIN
    THROW 50412,
          'The solver status contract was not applied.',
          1;
END;
GO