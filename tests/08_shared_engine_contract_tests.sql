SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.USP_SudokuFindFirstDeduction', N'P') IS NULL
    THROW 51070, 'Shared-engine test failed: internal deduction procedure is missing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.sql_modules AS ModuleDefinition
    WHERE ModuleDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P')
      AND ModuleDefinition.[definition] LIKE N'%EXEC dbo.USP_SudokuFindFirstDeduction%'
      AND ModuleDefinition.[definition] LIKE N'%target.[CandidateMask] & (511 & ~used.[UsedMask])%'
)
BEGIN
    THROW 51071, 'Shared-engine test failed: solver is not integrated or candidate eliminations are not preserved.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.sql_modules AS ModuleDefinition
    WHERE ModuleDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P')
      AND ModuleDefinition.[definition] LIKE N'%        -- Naked Single%'
)
BEGIN
    THROW 51072, 'Shared-engine test failed: duplicated explicit solver block remains installed.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.sql_modules AS ModuleDefinition
    WHERE ModuleDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuDiagnoseFirstDeduction', N'P')
      AND ModuleDefinition.[definition] LIKE N'%EXEC dbo.USP_SudokuFindFirstDeduction%'
)
BEGIN
    THROW 51073, 'Shared-engine test failed: diagnostic wrapper does not call the shared engine.', 1;
END;

DECLARE @CandidateState dbo.SudokuCandidateState;
DECLARE @EngineResult TABLE
(
    [SequenceNo] int,
    [TechniqueName] varchar(64),
    [ActionType] varchar(16),
    [Pos] tinyint,
    [Digit] tinyint NULL,
    [OldCandidateMask] smallint,
    [NewCandidateMask] smallint,
    [RemovedMask] smallint,
    [Evidence] nvarchar(2000)
);
DECLARE @WrapperResult TABLE
(
    [SequenceNo] int,
    [TechniqueName] varchar(64),
    [ActionType] varchar(16),
    [Pos] tinyint,
    [Digit] tinyint NULL,
    [OldCandidateMask] smallint,
    [NewCandidateMask] smallint,
    [RemovedMask] smallint,
    [Evidence] nvarchar(2000)
);

INSERT INTO @CandidateState ([Pos], [CandidateMask])
SELECT [Pos], CONVERT(smallint, 511)
FROM dbo.SudokuPos;

UPDATE @CandidateState
SET [CandidateMask] = 3
WHERE [Pos] IN (1, 2);

UPDATE @CandidateState
SET [CandidateMask] = 7
WHERE [Pos] = 3;

INSERT INTO @EngineResult
EXEC dbo.USP_SudokuFindFirstDeduction
    @Puzzle = '000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

INSERT INTO @WrapperResult
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = '000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF EXISTS
(
    SELECT * FROM @EngineResult
    EXCEPT
    SELECT * FROM @WrapperResult
)
OR EXISTS
(
    SELECT * FROM @WrapperResult
    EXCEPT
    SELECT * FROM @EngineResult
)
BEGIN
    THROW 51074, 'Shared-engine test failed: wrapper and engine results differ.', 1;
END;

PRINT 'Shared deduction engine contract tests passed.';