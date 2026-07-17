SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    Creates one shared explicit-deduction engine from the diagnostic source,
    replaces the public diagnostic procedure with a thin wrapper, and rewrites
    the explicit-technique section of dbo.USP_SudokuSolve to call the same
    engine.

    The installation fails when the expected source markers are absent or not
    unique. This prevents a partial or silent integration after future edits.
*/
DECLARE
    @DiagnosticDefinition nvarchar(max),
    @EngineDefinition nvarchar(max),
    @SolverDefinition nvarchar(max),
    @StartMarker nvarchar(200) = N'        -- Naked Single',
    @EndMarker nvarchar(200) = N'        -- Generalized advanced inference',
    @StartPosition int,
    @EndPosition int,
    @SecondStartPosition int,
    @SecondEndPosition int,
    @Replacement nvarchar(max);

SELECT
    @DiagnosticDefinition = ModuleDefinition.[definition]
FROM sys.sql_modules AS ModuleDefinition
WHERE ModuleDefinition.[object_id] =
      OBJECT_ID(N'dbo.USP_SudokuDiagnoseFirstDeduction', N'P');

IF @DiagnosticDefinition IS NULL
BEGIN
    THROW 50520,
          'The diagnostic procedure required to create the shared deduction engine was not found.',
          1;
END;

SET @EngineDefinition = REPLACE
(
    @DiagnosticDefinition,
    N'CREATE OR ALTER PROCEDURE dbo.USP_SudokuDiagnoseFirstDeduction',
    N'CREATE OR ALTER PROCEDURE dbo.USP_SudokuFindFirstDeduction'
);

IF @EngineDefinition = @DiagnosticDefinition
BEGIN
    THROW 50521,
          'The shared deduction engine procedure-name marker was not found.',
          1;
END;

/* A board string is always required by the shared engine. */
SET @EngineDefinition = REPLACE
(
    @EngineDefinition,
    N'IF @UseCandidateState = 0',
    N'IF 1 = 1'
);

/* Solved positions use mask 0; unsolved positions use masks 1 through 511. */
SET @EngineDefinition = REPLACE
(
    @EngineDefinition,
    N'WHERE [CandidateMask] NOT BETWEEN 1 AND 511',
    N'WHERE [CandidateMask] NOT BETWEEN 0 AND 511'
);

SET @EngineDefinition = REPLACE
(
    @EngineDefinition,
    N'Candidate state must contain exactly 81 positions with masks from 1 through 511.',
    N'Candidate state must contain exactly 81 positions with masks from 0 through 511.'
);

SET @EngineDefinition = REPLACE
(
    @EngineDefinition,
    N'THEN ''0''',
    N'THEN SUBSTRING(@Puzzle, position.[Pos], 1)'
);

SET @EngineDefinition = REPLACE
(
    @EngineDefinition,
    N'    CREATE TABLE #BoardCells',
    N'    IF @UseCandidateState = 1
       AND EXISTS
           (
               SELECT 1
               FROM @CandidateState AS Candidate
               WHERE
                   (
                       SUBSTRING(@Puzzle, Candidate.[Pos], 1) = ''0''
                       AND Candidate.[CandidateMask] = 0
                   )
                   OR
                   (
                       SUBSTRING(@Puzzle, Candidate.[Pos], 1) <> ''0''
                       AND Candidate.[CandidateMask] <> 0
                   )
           )
    BEGIN
        THROW 50502,
              ''Solved positions require mask 0 and unsolved positions require a nonzero candidate mask.'',
              1;
    END;

    CREATE TABLE #BoardCells'
);

IF @EngineDefinition NOT LIKE N'%USP_SudokuFindFirstDeduction%'
   OR @EngineDefinition NOT LIKE N'%THROW 50502%'
BEGIN
    THROW 50522,
          'The shared deduction engine definition could not be normalized safely.',
          1;
END;

EXEC sys.sp_executesql @EngineDefinition;
GO

CREATE OR ALTER PROCEDURE dbo.USP_SudokuDiagnoseFirstDeduction
(
    @Puzzle            char(81) = NULL,
    @CandidateState    dbo.SudokuCandidateState READONLY,
    @UseCandidateState bit = 0,
    @Help              bit = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Help = 1
    BEGIN
        PRINT 'dbo.USP_SudokuDiagnoseFirstDeduction';
        PRINT 'Returns the first deterministic explicit deduction without changing persistent data.';
        PRINT '@Puzzle: 81 digits, where 0 represents an empty cell.';
        PRINT '@CandidateState: optional complete 81-row board candidate state.';
        PRINT '@UseCandidateState: use supplied masks; solved positions require mask 0.';
        RETURN;
    END;

    DECLARE @EffectivePuzzle char(81) = @Puzzle;

    IF @UseCandidateState = 1 AND @EffectivePuzzle IS NULL
        SET @EffectivePuzzle = REPLICATE(CONVERT(varchar(max), '0'), 81);

    EXEC dbo.USP_SudokuFindFirstDeduction
        @Puzzle = @EffectivePuzzle,
        @CandidateState = @CandidateState,
        @UseCandidateState = @UseCandidateState,
        @Help = 0;
END;
GO

DECLARE
    @SolverDefinition nvarchar(max),
    @StartMarker nvarchar(200) = N'        -- Naked Single',
    @EndMarker nvarchar(200) = N'        -- Generalized advanced inference',
    @StartPosition int,
    @EndPosition int,
    @SecondStartPosition int,
    @SecondEndPosition int,
    @Replacement nvarchar(max);

SELECT
    @SolverDefinition = ModuleDefinition.[definition]
FROM sys.sql_modules AS ModuleDefinition
WHERE ModuleDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P');

IF @SolverDefinition IS NULL
BEGIN
    THROW 50523,
          'The solver procedure required for shared deduction integration was not found.',
          1;
END;

/* Preserve previous logical eliminations during candidate refresh. */
SET @SolverDefinition = REPLACE
(
    @SolverDefinition,
    N'CONVERT(smallint, 511 & ~used.[UsedMask])',
    N'CONVERT(smallint, target.[CandidateMask] & (511 & ~used.[UsedMask]))'
);

IF @SolverDefinition NOT LIKE
   N'%target.[CandidateMask] & (511 & ~used.[UsedMask])%'
BEGIN
    THROW 50524,
          'The candidate-refresh preservation marker was not found.',
          1;
END;

SET @StartPosition = CHARINDEX(@StartMarker, @SolverDefinition);
SET @EndPosition = CHARINDEX(@EndMarker, @SolverDefinition);
SET @SecondStartPosition = CHARINDEX(@StartMarker, @SolverDefinition, @StartPosition + 1);
SET @SecondEndPosition = CHARINDEX(@EndMarker, @SolverDefinition, @EndPosition + 1);

IF @StartPosition = 0
   OR @EndPosition = 0
   OR @StartPosition >= @EndPosition
   OR @SecondStartPosition <> 0
   OR @SecondEndPosition <> 0
BEGIN
    THROW 50525,
          'The explicit-technique solver block could not be identified uniquely.',
          1;
END;

SET @Replacement = N'        -- Shared explicit deduction engine
        -----------------------------------------------------------------------
        DECLARE @SharedCandidateState dbo.SudokuCandidateState;
        DECLARE @SharedDeduction TABLE
        (
            [SequenceNo] int NOT NULL,
            [TechniqueName] varchar(64) NOT NULL,
            [ActionType] varchar(16) NOT NULL,
            [Pos] tinyint NOT NULL,
            [Digit] tinyint NULL,
            [OldCandidateMask] smallint NOT NULL,
            [NewCandidateMask] smallint NOT NULL,
            [RemovedMask] smallint NOT NULL,
            [Evidence] nvarchar(2000) NOT NULL
        );

        INSERT INTO @SharedCandidateState
        (
            [Pos],
            [CandidateMask]
        )
        SELECT
            board.[Pos],
            board.[CandidateMask]
        FROM #BoardCells AS board;

        SELECT
            @BoardBefore =
                STRING_AGG(CONVERT(varchar(max), board.[Digit]), '''')
                WITHIN GROUP (ORDER BY board.[Pos])
        FROM #BoardCells AS board;

        INSERT INTO @SharedDeduction
        (
            [SequenceNo],
            [TechniqueName],
            [ActionType],
            [Pos],
            [Digit],
            [OldCandidateMask],
            [NewCandidateMask],
            [RemovedMask],
            [Evidence]
        )
        EXEC dbo.USP_SudokuFindFirstDeduction
            @Puzzle = @BoardBefore,
            @CandidateState = @SharedCandidateState,
            @UseCandidateState = 1,
            @Help = 0;

        IF EXISTS (SELECT 1 FROM @SharedDeduction)
        BEGIN
            UPDATE board
            SET
                board.[Digit] = CONVERT(char(1), deduction.[Digit]),
                board.[CandidateMask] = 0
            FROM #BoardCells AS board
            INNER JOIN @SharedDeduction AS deduction
                ON deduction.[Pos] = board.[Pos]
               AND deduction.[ActionType] = ''Set'';

            UPDATE board
            SET board.[CandidateMask] = deduction.[NewCandidateMask]
            FROM #BoardCells AS board
            INNER JOIN @SharedDeduction AS deduction
                ON deduction.[Pos] = board.[Pos]
               AND deduction.[ActionType] = ''Eliminate'';

            SELECT
                @BoardAfter =
                    STRING_AGG(CONVERT(varchar(max), board.[Digit]), '''')
                    WITHIN GROUP (ORDER BY board.[Pos])
            FROM #BoardCells AS board;

            INSERT INTO #TechniqueLog
            (
                [IterationNo],
                [TechniqueName],
                [ActionType],
                [Pos],
                [Digit],
                [OldCandidateMask],
                [NewCandidateMask],
                [RemovedMask],
                [ElapsedMicroseconds],
                [Details],
                [BoardBefore],
                [BoardAfter]
            )
            SELECT
                @IterationNumber,
                deduction.[TechniqueName],
                deduction.[ActionType],
                deduction.[Pos],
                deduction.[Digit],
                deduction.[OldCandidateMask],
                deduction.[NewCandidateMask],
                deduction.[RemovedMask],
                0,
                deduction.[Evidence],
                @BoardBefore,
                @BoardAfter
            FROM @SharedDeduction AS deduction
            ORDER BY deduction.[SequenceNo];

            SET @Changed = 1;

            IF @SingleStep = 1
                BREAK;

            CONTINUE;
        END;

        -----------------------------------------------------------------------
';

SET @SolverDefinition =
    STUFF
    (
        @SolverDefinition,
        @StartPosition,
        @EndPosition - @StartPosition,
        @Replacement
    );

IF @SolverDefinition NOT LIKE N'%USP_SudokuFindFirstDeduction%'
   OR @SolverDefinition LIKE N'%        -- Naked Single%'
BEGIN
    THROW 50526,
          'The solver was not rewritten to use the shared deduction engine.',
          1;
END;

EXEC sys.sp_executesql @SolverDefinition;
GO

IF OBJECT_ID(N'dbo.USP_SudokuFindFirstDeduction', N'P') IS NULL
   OR OBJECT_ID(N'dbo.USP_SudokuDiagnoseFirstDeduction', N'P') IS NULL
BEGIN
    THROW 50527,
          'Shared deduction engine installation did not create all required procedures.',
          1;
END;
GO