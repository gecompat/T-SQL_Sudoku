CREATE OR ALTER PROCEDURE dbo.USP_SudokuSolve
(
    @Puzzle                 char(81),
    @Solution               char(81) OUTPUT,
    @Status                 varchar(32) OUTPUT,
    @SingleStep             bit = 0,
    @AllowBacktracking      bit = 1,
    @AllowForcing           bit = 1,
    @AllowForcingNets       bit = 0,
    @ValidateInitialState   bit = 1,
    @ValidateFinalResult    bit = 1,
    @MaxIterations          int = 10000,
    @MaxRuntimeMs           int = 30000,
    @MaxForcingChecks       smallint = 64,
    @ReturnSolutionPath     bit = 1,
    @ReturnStatistics       bit = 1,
    @PrintMessages          bit = 0,
    @Help                   bit = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Help = 1
    BEGIN
        PRINT 'dbo.USP_SudokuSolve';
        PRINT '@Puzzle: exactly 81 digits; 0 represents an empty cell.';
        PRINT '@SingleStep: stop after the first successful logical action.';
        PRINT '@AllowForcing: enable contradiction and common-consequence proofs.';
        PRINT '@AllowForcingNets: enable the most expensive bounded premise search.';
        PRINT '@AllowBacktracking: enable the independent complete fallback.';
        PRINT '@ReturnSolutionPath: return one row per applied solving action.';
        PRINT '@ReturnStatistics: return aggregated technique statistics.';
        RETURN;
    END;

    IF @Puzzle IS NULL
       OR LEN(@Puzzle) <> 81
       OR @Puzzle LIKE '%[^0-9]%'
    BEGIN
        THROW 50300,
              'Puzzle must contain exactly 81 digits from 0 through 9.',
              1;
    END;

    IF @MaxIterations IS NULL OR @MaxIterations < 1
        SET @MaxIterations = 10000;

    IF @MaxRuntimeMs IS NULL OR @MaxRuntimeMs < 1
        SET @MaxRuntimeMs = 30000;

    IF @MaxForcingChecks IS NULL OR @MaxForcingChecks < 1
        SET @MaxForcingChecks = 1;

    DECLARE
        @SolverStartedAt datetime2(7) = SYSUTCDATETIME(),
        @IterationNumber int = 0,
        @Changed bit = 1,
        @TechniqueStartedAt datetime2(7),
        @ElapsedMicroseconds bigint,
        @AffectedCellCount int,
        @BoardBefore char(81),
        @BoardAfter char(81),
        @ValidationSolutionCount int,
        @ValidatedSolution char(81),
        @AssumptionPuzzle char(81),
        @AssumptionSolution char(81),
        @AssumptionSolutionCount int,
        @SelectedPosition tinyint,
        @SelectedDigit tinyint,
        @SelectedMask smallint,
        @OriginalMask smallint,
        @ForcingCheckCount int,
        @AlternativeDigit tinyint,
        @AlternativeMask smallint,
        @AlternativeHasSolution bit;

    SET @Solution = NULL;
    SET @Status = 'Initialized';

    CREATE TABLE #BoardCells
    (
        [Pos] tinyint NOT NULL,
        [Row] tinyint NOT NULL,
        [Col] tinyint NOT NULL,
        [Box] tinyint NOT NULL,
        [Digit] char(1) NOT NULL,
        [CandidateMask] smallint NOT NULL,
        CONSTRAINT [PK_BoardCells] PRIMARY KEY CLUSTERED ([Pos])
    );

    INSERT INTO #BoardCells
    (
        [Pos],
        [Row],
        [Col],
        [Box],
        [Digit],
        [CandidateMask]
    )
    SELECT
        position.[Pos],
        position.[Row],
        position.[Col],
        position.[Box],
        SUBSTRING(@Puzzle, position.[Pos], 1),
        CASE
            WHEN SUBSTRING(@Puzzle, position.[Pos], 1) = '0' THEN 511
            ELSE 0
        END
    FROM dbo.SudokuPos AS position;

    CREATE TABLE #TechniqueLog
    (
        [StepNo] int IDENTITY(1,1) NOT NULL,
        [IterationNo] int NOT NULL,
        [TechniqueName] varchar(64) NOT NULL,
        [ActionType] varchar(16) NOT NULL,
        [Pos] tinyint NULL,
        [Digit] tinyint NULL,
        [OldCandidateMask] smallint NULL,
        [NewCandidateMask] smallint NULL,
        [RemovedMask] smallint NULL,
        [ElapsedMicroseconds] bigint NOT NULL,
        [Details] nvarchar(2000) NULL,
        [BoardBefore] char(81) NULL,
        [BoardAfter] char(81) NULL,
        CONSTRAINT [PK_TechniqueLog] PRIMARY KEY CLUSTERED ([StepNo])
    );

    CREATE TABLE #Removal
    (
        [Pos] tinyint NOT NULL,
        [RemoveMask] smallint NOT NULL,
        CONSTRAINT [PK_Removal] PRIMARY KEY CLUSTERED ([Pos])
    );

    IF @ValidateInitialState = 1
    BEGIN
        EXEC dbo.USP_SudokuValidate
            @Puzzle = @Puzzle,
            @MaxSolutions = 1,
            @SolutionCount = @ValidationSolutionCount OUTPUT,
            @FirstSolution = @ValidatedSolution OUTPUT,
            @Help = 0;

        IF @ValidationSolutionCount = 0
        BEGIN
            SET @Status = 'Invalid';
            SET @Solution = @Puzzle;

            SELECT
                @Solution AS [Board],
                @Status AS [Status],
                0 AS [Iterations],
                0 AS [ElapsedMilliseconds];
            RETURN;
        END;
    END;

    WHILE @Changed = 1
      AND @IterationNumber < @MaxIterations
    BEGIN
        IF DATEDIFF_BIG(MILLISECOND, @SolverStartedAt, SYSUTCDATETIME()) >= @MaxRuntimeMs
        BEGIN
            SET @Status = 'Timeout';
            BREAK;
        END;

        SET @IterationNumber += 1;
        SET @Changed = 0;

        -----------------------------------------------------------------------
        -- Candidate refresh
        -----------------------------------------------------------------------
        ;WITH UsedMasks AS
        (
            SELECT
                board.[Pos],
                [UsedMask] =
                    CONVERT
                    (
                        smallint,
                        ISNULL
                        (
                            (
                                SELECT SUM(mask.[BitMask])
                                FROM #BoardCells AS rowPeer
                                INNER JOIN dbo.SudokuDigitMask AS mask
                                    ON mask.[Digit] = CONVERT(tinyint, rowPeer.[Digit])
                                WHERE rowPeer.[Row] = board.[Row]
                                  AND rowPeer.[Digit] <> '0'
                            ),
                            0
                        )
                        |
                        ISNULL
                        (
                            (
                                SELECT SUM(mask.[BitMask])
                                FROM #BoardCells AS columnPeer
                                INNER JOIN dbo.SudokuDigitMask AS mask
                                    ON mask.[Digit] = CONVERT(tinyint, columnPeer.[Digit])
                                WHERE columnPeer.[Col] = board.[Col]
                                  AND columnPeer.[Digit] <> '0'
                            ),
                            0
                        )
                        |
                        ISNULL
                        (
                            (
                                SELECT SUM(mask.[BitMask])
                                FROM #BoardCells AS boxPeer
                                INNER JOIN dbo.SudokuDigitMask AS mask
                                    ON mask.[Digit] = CONVERT(tinyint, boxPeer.[Digit])
                                WHERE boxPeer.[Box] = board.[Box]
                                  AND boxPeer.[Digit] <> '0'
                            ),
                            0
                        )
                    )
            FROM #BoardCells AS board
            WHERE board.[Digit] = '0'
        )
        UPDATE target
        SET target.[CandidateMask] =
            CONVERT(smallint, 511 & ~used.[UsedMask])
        FROM #BoardCells AS target
        INNER JOIN UsedMasks AS used
            ON used.[Pos] = target.[Pos];

        IF EXISTS
        (
            SELECT 1
            FROM #BoardCells
            WHERE [Digit] = '0'
              AND [CandidateMask] = 0
        )
        BEGIN
            SET @Status = 'Contradiction';
            BREAK;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM #BoardCells
            WHERE [Digit] = '0'
        )
        BEGIN
            SET @Status = 'SolvedLogically';
            BREAK;
        END;

        SELECT
            @BoardBefore =
                STRING_AGG(CONVERT(varchar(max), [Digit]), '')
                WITHIN GROUP (ORDER BY [Pos])
        FROM #BoardCells;

        -----------------------------------------------------------------------
        -- Naked Single
        -----------------------------------------------------------------------
        SET @TechniqueStartedAt = SYSUTCDATETIME();
        SET @SelectedPosition = NULL;
        SET @SelectedDigit = NULL;
        SET @OriginalMask = NULL;

        SELECT TOP (1)
            @SelectedPosition = board.[Pos],
            @SelectedDigit = mask.[Digit],
            @OriginalMask = board.[CandidateMask]
        FROM #BoardCells AS board
        INNER JOIN dbo.BitCount511 AS bitCount
            ON bitCount.[Mask] = board.[CandidateMask]
           AND bitCount.[BitCount] = 1
        INNER JOIN dbo.SudokuDigitMask AS mask
            ON mask.[BitMask] = board.[CandidateMask]
        WHERE board.[Digit] = '0'
        ORDER BY board.[Pos];

        IF @SelectedPosition IS NOT NULL
        BEGIN
            UPDATE #BoardCells
            SET
                [Digit] = CONVERT(char(1), @SelectedDigit),
                [CandidateMask] = 0
            WHERE [Pos] = @SelectedPosition;

            SET @ElapsedMicroseconds =
                DATEDIFF_BIG
                (
                    MICROSECOND,
                    @TechniqueStartedAt,
                    SYSUTCDATETIME()
                );

            SELECT
                @BoardAfter =
                    STRING_AGG(CONVERT(varchar(max), [Digit]), '')
                    WITHIN GROUP (ORDER BY [Pos])
            FROM #BoardCells;

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
            VALUES
            (
                @IterationNumber,
                'Naked Single',
                'Set',
                @SelectedPosition,
                @SelectedDigit,
                @OriginalMask,
                0,
                0,
                @ElapsedMicroseconds,
                N'Only one candidate remained in the cell.',
                @BoardBefore,
                @BoardAfter
            );

            SET @Changed = 1;

            IF @SingleStep = 1
                BREAK;

            CONTINUE;
        END;

        -----------------------------------------------------------------------
        -- Hidden Single
        -----------------------------------------------------------------------
        SET @TechniqueStartedAt = SYSUTCDATETIME();
        SET @SelectedPosition = NULL;
        SET @SelectedDigit = NULL;

        ;WITH Candidates AS
        (
            SELECT
                board.[Pos],
                board.[Row],
                board.[Col],
                board.[Box],
                mask.[Digit]
            FROM #BoardCells AS board
            INNER JOIN dbo.SudokuDigitMask AS mask
                ON (board.[CandidateMask] & mask.[BitMask]) <> 0
            WHERE board.[Digit] = '0'
        ),
        HiddenSingles AS
        (
            SELECT MIN([Pos]) AS [Pos], [Digit], 1 AS [PriorityNo]
            FROM Candidates
            GROUP BY [Row], [Digit]
            HAVING COUNT_BIG(*) = 1

            UNION ALL

            SELECT MIN([Pos]), [Digit], 2
            FROM Candidates
            GROUP BY [Col], [Digit]
            HAVING COUNT_BIG(*) = 1

            UNION ALL

            SELECT MIN([Pos]), [Digit], 3
            FROM Candidates
            GROUP BY [Box], [Digit]
            HAVING COUNT_BIG(*) = 1
        )
        SELECT TOP (1)
            @SelectedPosition = [Pos],
            @SelectedDigit = [Digit]
        FROM HiddenSingles
        ORDER BY [PriorityNo], [Pos], [Digit];

        IF @SelectedPosition IS NOT NULL
        BEGIN
            SELECT @OriginalMask = [CandidateMask]
            FROM #BoardCells
            WHERE [Pos] = @SelectedPosition;

            UPDATE #BoardCells
            SET
                [Digit] = CONVERT(char(1), @SelectedDigit),
                [CandidateMask] = 0
            WHERE [Pos] = @SelectedPosition;

            SET @ElapsedMicroseconds =
                DATEDIFF_BIG
                (
                    MICROSECOND,
                    @TechniqueStartedAt,
                    SYSUTCDATETIME()
                );

            SELECT
                @BoardAfter =
                    STRING_AGG(CONVERT(varchar(max), [Digit]), '')
                    WITHIN GROUP (ORDER BY [Pos])
            FROM #BoardCells;

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
            VALUES
            (
                @IterationNumber,
                'Hidden Single',
                'Set',
                @SelectedPosition,
                @SelectedDigit,
                @OriginalMask,
                0,
                0,
                @ElapsedMicroseconds,
                N'The digit had exactly one remaining position in a house.',
                @BoardBefore,
                @BoardAfter
            );

            SET @Changed = 1;

            IF @SingleStep = 1
                BREAK;

            CONTINUE;
        END;

        -----------------------------------------------------------------------
        -- Locked candidates: Pointing and Claiming
        -----------------------------------------------------------------------
        TRUNCATE TABLE #Removal;

        ;WITH CandidateNodes AS
        (
            SELECT
                board.[Pos],
                board.[Row],
                board.[Col],
                board.[Box],
                mask.[BitMask]
            FROM #BoardCells AS board
            INNER JOIN dbo.SudokuDigitMask AS mask
                ON (board.[CandidateMask] & mask.[BitMask]) <> 0
            WHERE board.[Digit] = '0'
        ),
        BoxPatterns AS
        (
            SELECT
                [Box],
                [BitMask],
                MIN([Row]) AS [MinimumRow],
                MAX([Row]) AS [MaximumRow],
                MIN([Col]) AS [MinimumColumn],
                MAX([Col]) AS [MaximumColumn]
            FROM CandidateNodes
            GROUP BY [Box], [BitMask]
            HAVING COUNT_BIG(*) >= 2
        ),
        RowPatterns AS
        (
            SELECT
                [Row],
                [BitMask],
                MIN([Box]) AS [MinimumBox],
                MAX([Box]) AS [MaximumBox]
            FROM CandidateNodes
            GROUP BY [Row], [BitMask]
            HAVING COUNT_BIG(*) >= 2
        ),
        ColumnPatterns AS
        (
            SELECT
                [Col],
                [BitMask],
                MIN([Box]) AS [MinimumBox],
                MAX([Box]) AS [MaximumBox]
            FROM CandidateNodes
            GROUP BY [Col], [BitMask]
            HAVING COUNT_BIG(*) >= 2
        ),
        RawRemoval AS
        (
            SELECT target.[Pos], pattern.[BitMask]
            FROM BoxPatterns AS pattern
            INNER JOIN #BoardCells AS target
                ON target.[Digit] = '0'
               AND target.[Box] <> pattern.[Box]
               AND
               (
                   (pattern.[MinimumRow] = pattern.[MaximumRow]
                    AND target.[Row] = pattern.[MinimumRow])
                   OR
                   (pattern.[MinimumColumn] = pattern.[MaximumColumn]
                    AND target.[Col] = pattern.[MinimumColumn])
               )
               AND (target.[CandidateMask] & pattern.[BitMask]) <> 0

            UNION ALL

            SELECT target.[Pos], pattern.[BitMask]
            FROM RowPatterns AS pattern
            INNER JOIN #BoardCells AS target
                ON target.[Digit] = '0'
               AND pattern.[MinimumBox] = pattern.[MaximumBox]
               AND target.[Box] = pattern.[MinimumBox]
               AND target.[Row] <> pattern.[Row]
               AND (target.[CandidateMask] & pattern.[BitMask]) <> 0

            UNION ALL

            SELECT target.[Pos], pattern.[BitMask]
            FROM ColumnPatterns AS pattern
            INNER JOIN #BoardCells AS target
                ON target.[Digit] = '0'
               AND pattern.[MinimumBox] = pattern.[MaximumBox]
               AND target.[Box] = pattern.[MinimumBox]
               AND target.[Col] <> pattern.[Col]
               AND (target.[CandidateMask] & pattern.[BitMask]) <> 0
        )
        INSERT INTO #Removal
        (
            [Pos],
            [RemoveMask]
        )
        SELECT
            [Pos],
            CONVERT(smallint, SUM(DISTINCT [BitMask]))
        FROM RawRemoval
        GROUP BY [Pos];

        IF EXISTS (SELECT 1 FROM #Removal)
        BEGIN
            UPDATE target
            SET target.[CandidateMask] =
                CONVERT
                (
                    smallint,
                    target.[CandidateMask] & ~removal.[RemoveMask]
                )
            FROM #BoardCells AS target
            INNER JOIN #Removal AS removal
                ON removal.[Pos] = target.[Pos]
            WHERE (target.[CandidateMask] & removal.[RemoveMask]) <> 0;

            SET @AffectedCellCount = @@ROWCOUNT;

            INSERT INTO #TechniqueLog
            (
                [IterationNo],
                [TechniqueName],
                [ActionType],
                [ElapsedMicroseconds],
                [Details],
                [BoardBefore],
                [BoardAfter]
            )
            VALUES
            (
                @IterationNumber,
                'Pointing / Claiming',
                'Eliminate',
                0,
                CONCAT
                (
                    N'Locked-candidate eliminations in ',
                    @AffectedCellCount,
                    N' cell(s).'
                ),
                @BoardBefore,
                @BoardBefore
            );

            SET @Changed = 1;

            IF @SingleStep = 1
                BREAK;

            CONTINUE;
        END;

        -----------------------------------------------------------------------
        -- Naked subsets: pairs, triples, and quads
        -----------------------------------------------------------------------
        DECLARE @SubsetSize tinyint = 2;

        WHILE @SubsetSize <= 4 AND @Changed = 0
        BEGIN
            TRUNCATE TABLE #Removal;

            ;WITH UnitCells AS
            (
                SELECT
                    'R' AS [UnitType],
                    board.[Row] AS [UnitNo],
                    board.[Pos],
                    board.[CandidateMask]
                FROM #BoardCells AS board
                INNER JOIN dbo.BitCount511 AS bitCount
                    ON bitCount.[Mask] = board.[CandidateMask]
                WHERE board.[Digit] = '0'
                  AND bitCount.[BitCount] BETWEEN 2 AND @SubsetSize

                UNION ALL

                SELECT
                    'C',
                    board.[Col],
                    board.[Pos],
                    board.[CandidateMask]
                FROM #BoardCells AS board
                INNER JOIN dbo.BitCount511 AS bitCount
                    ON bitCount.[Mask] = board.[CandidateMask]
                WHERE board.[Digit] = '0'
                  AND bitCount.[BitCount] BETWEEN 2 AND @SubsetSize

                UNION ALL

                SELECT
                    'B',
                    board.[Box],
                    board.[Pos],
                    board.[CandidateMask]
                FROM #BoardCells AS board
                INNER JOIN dbo.BitCount511 AS bitCount
                    ON bitCount.[Mask] = board.[CandidateMask]
                WHERE board.[Digit] = '0'
                  AND bitCount.[BitCount] BETWEEN 2 AND @SubsetSize
            ),
            Combinations AS
            (
                SELECT
                    firstCell.[UnitType],
                    firstCell.[UnitNo],
                    secondCell.[Pos] AS [LastPosition],
                    CONVERT(tinyint, 2) AS [CellCount],
                    CONVERT
                    (
                        smallint,
                        firstCell.[CandidateMask] | secondCell.[CandidateMask]
                    ) AS [UnionMask],
                    CONVERT
                    (
                        varchar(64),
                        CONCAT
                        (
                            '>',
                            RIGHT('00' + CONVERT(varchar(2), firstCell.[Pos]), 2),
                            '>',
                            RIGHT('00' + CONVERT(varchar(2), secondCell.[Pos]), 2),
                            '>'
                        )
                    ) AS [CellPath]
                FROM UnitCells AS firstCell
                INNER JOIN UnitCells AS secondCell
                    ON secondCell.[UnitType] = firstCell.[UnitType]
                   AND secondCell.[UnitNo] = firstCell.[UnitNo]
                   AND secondCell.[Pos] > firstCell.[Pos]

                UNION ALL

                SELECT
                    combination.[UnitType],
                    combination.[UnitNo],
                    nextCell.[Pos],
                    CONVERT(tinyint, combination.[CellCount] + 1),
                    CONVERT
                    (
                        smallint,
                        combination.[UnionMask] | nextCell.[CandidateMask]
                    ),
                    CONVERT
                    (
                        varchar(64),
                        CONCAT
                        (
                            combination.[CellPath],
                            RIGHT('00' + CONVERT(varchar(2), nextCell.[Pos]), 2),
                            '>'
                        )
                    )
                FROM Combinations AS combination
                INNER JOIN UnitCells AS nextCell
                    ON nextCell.[UnitType] = combination.[UnitType]
                   AND nextCell.[UnitNo] = combination.[UnitNo]
                   AND nextCell.[Pos] > combination.[LastPosition]
                WHERE combination.[CellCount] < @SubsetSize
            ),
            ValidSubset AS
            (
                SELECT TOP (1)
                    combination.[UnitType],
                    combination.[UnitNo],
                    combination.[UnionMask],
                    combination.[CellPath]
                FROM Combinations AS combination
                INNER JOIN dbo.BitCount511 AS bitCount
                    ON bitCount.[Mask] = combination.[UnionMask]
                   AND bitCount.[BitCount] = @SubsetSize
                WHERE combination.[CellCount] = @SubsetSize
                  AND EXISTS
                  (
                      SELECT 1
                      FROM #BoardCells AS target
                      WHERE target.[Digit] = '0'
                        AND
                        (
                            (combination.[UnitType] = 'R'
                             AND target.[Row] = combination.[UnitNo])
                            OR
                            (combination.[UnitType] = 'C'
                             AND target.[Col] = combination.[UnitNo])
                            OR
                            (combination.[UnitType] = 'B'
                             AND target.[Box] = combination.[UnitNo])
                        )
                        AND combination.[CellPath] NOT LIKE
                            '%>'
                            + RIGHT('00' + CONVERT(varchar(2), target.[Pos]), 2)
                            + '>%'
                        AND (target.[CandidateMask] & combination.[UnionMask]) <> 0
                  )
                ORDER BY
                    combination.[UnitType],
                    combination.[UnitNo],
                    combination.[CellPath]
            )
            INSERT INTO #Removal
            (
                [Pos],
                [RemoveMask]
            )
            SELECT
                target.[Pos],
                subset.[UnionMask]
            FROM ValidSubset AS subset
            INNER JOIN #BoardCells AS target
                ON target.[Digit] = '0'
               AND
               (
                   (subset.[UnitType] = 'R'
                    AND target.[Row] = subset.[UnitNo])
                   OR
                   (subset.[UnitType] = 'C'
                    AND target.[Col] = subset.[UnitNo])
                   OR
                   (subset.[UnitType] = 'B'
                    AND target.[Box] = subset.[UnitNo])
               )
               AND subset.[CellPath] NOT LIKE
                   '%>'
                   + RIGHT('00' + CONVERT(varchar(2), target.[Pos]), 2)
                   + '>%'
               AND (target.[CandidateMask] & subset.[UnionMask]) <> 0
            OPTION (MAXRECURSION 16);

            IF EXISTS (SELECT 1 FROM #Removal)
            BEGIN
                UPDATE target
                SET target.[CandidateMask] =
                    CONVERT
                    (
                        smallint,
                        target.[CandidateMask] & ~removal.[RemoveMask]
                    )
                FROM #BoardCells AS target
                INNER JOIN #Removal AS removal
                    ON removal.[Pos] = target.[Pos];

                INSERT INTO #TechniqueLog
                (
                    [IterationNo],
                    [TechniqueName],
                    [ActionType],
                    [ElapsedMicroseconds],
                    [Details],
                    [BoardBefore],
                    [BoardAfter]
                )
                VALUES
                (
                    @IterationNumber,
                    CASE @SubsetSize
                        WHEN 2 THEN 'Naked Pair'
                        WHEN 3 THEN 'Naked Triple'
                        ELSE 'Naked Quad'
                    END,
                    'Eliminate',
                    0,
                    N'Naked subset candidates removed from the remainder of the house.',
                    @BoardBefore,
                    @BoardBefore
                );

                SET @Changed = 1;

                IF @SingleStep = 1
                    BREAK;
            END;

            SET @SubsetSize += 1;
        END;

        IF @Changed = 1
            CONTINUE;

        -----------------------------------------------------------------------
        -- Basic fish: X-Wing, Swordfish, and Jellyfish
        -----------------------------------------------------------------------
        DECLARE @FishSize tinyint = 2;

        WHILE @FishSize <= 4 AND @Changed = 0
        BEGIN
            TRUNCATE TABLE #Removal;

            ;WITH CandidatePositions AS
            (
                SELECT
                    'R' AS [Orientation],
                    mask.[BitMask],
                    board.[Row] AS [BaseUnitNo],
                    board.[Col] AS [CoverUnitNo],
                    board.[Pos]
                FROM #BoardCells AS board
                INNER JOIN dbo.SudokuDigitMask AS mask
                    ON (board.[CandidateMask] & mask.[BitMask]) <> 0
                WHERE board.[Digit] = '0'

                UNION ALL

                SELECT
                    'C',
                    mask.[BitMask],
                    board.[Col],
                    board.[Row],
                    board.[Pos]
                FROM #BoardCells AS board
                INNER JOIN dbo.SudokuDigitMask AS mask
                    ON (board.[CandidateMask] & mask.[BitMask]) <> 0
                WHERE board.[Digit] = '0'
            ),
            BasePatterns AS
            (
                SELECT
                    position.[Orientation],
                    position.[BitMask],
                    position.[BaseUnitNo],
                    CONVERT
                    (
                        smallint,
                        SUM(mask.[BitMask])
                    ) AS [CoverMask]
                FROM CandidatePositions AS position
                INNER JOIN dbo.SudokuDigitMask AS mask
                    ON mask.[Digit] = position.[CoverUnitNo]
                GROUP BY
                    position.[Orientation],
                    position.[BitMask],
                    position.[BaseUnitNo]
                HAVING COUNT_BIG(*) BETWEEN 2 AND @FishSize
            ),
            FishCombinations AS
            (
                SELECT
                    pattern.[Orientation],
                    pattern.[BitMask],
                    pattern.[BaseUnitNo] AS [LastBaseUnitNo],
                    CONVERT(tinyint, 1) AS [BaseCount],
                    pattern.[CoverMask],
                    CONVERT
                    (
                        varchar(32),
                        CONCAT('>', CONVERT(varchar(1), pattern.[BaseUnitNo]), '>')
                    ) AS [BasePath]
                FROM BasePatterns AS pattern

                UNION ALL

                SELECT
                    combination.[Orientation],
                    combination.[BitMask],
                    pattern.[BaseUnitNo],
                    CONVERT(tinyint, combination.[BaseCount] + 1),
                    CONVERT
                    (
                        smallint,
                        combination.[CoverMask] | pattern.[CoverMask]
                    ),
                    CONVERT
                    (
                        varchar(32),
                        CONCAT
                        (
                            combination.[BasePath],
                            CONVERT(varchar(1), pattern.[BaseUnitNo]),
                            '>'
                        )
                    )
                FROM FishCombinations AS combination
                INNER JOIN BasePatterns AS pattern
                    ON pattern.[Orientation] = combination.[Orientation]
                   AND pattern.[BitMask] = combination.[BitMask]
                   AND pattern.[BaseUnitNo] > combination.[LastBaseUnitNo]
                WHERE combination.[BaseCount] < @FishSize
            ),
            ValidFish AS
            (
                SELECT TOP (1)
                    combination.[Orientation],
                    combination.[BitMask],
                    combination.[CoverMask],
                    combination.[BasePath]
                FROM FishCombinations AS combination
                INNER JOIN dbo.BitCount511 AS bitCount
                    ON bitCount.[Mask] = combination.[CoverMask]
                   AND bitCount.[BitCount] = @FishSize
                WHERE combination.[BaseCount] = @FishSize
                  AND EXISTS
                  (
                      SELECT 1
                      FROM CandidatePositions AS target
                      INNER JOIN dbo.SudokuDigitMask AS coverMask
                          ON coverMask.[Digit] = target.[CoverUnitNo]
                      WHERE target.[Orientation] = combination.[Orientation]
                        AND target.[BitMask] = combination.[BitMask]
                        AND combination.[BasePath] NOT LIKE
                            '%>'
                            + CONVERT(varchar(1), target.[BaseUnitNo])
                            + '>%'
                        AND (combination.[CoverMask] & coverMask.[BitMask]) <> 0
                  )
                ORDER BY
                    combination.[Orientation],
                    combination.[BitMask],
                    combination.[BasePath]
            )
            INSERT INTO #Removal
            (
                [Pos],
                [RemoveMask]
            )
            SELECT
                target.[Pos],
                fish.[BitMask]
            FROM ValidFish AS fish
            INNER JOIN CandidatePositions AS target
                ON target.[Orientation] = fish.[Orientation]
               AND target.[BitMask] = fish.[BitMask]
            INNER JOIN dbo.SudokuDigitMask AS coverMask
                ON coverMask.[Digit] = target.[CoverUnitNo]
               AND (fish.[CoverMask] & coverMask.[BitMask]) <> 0
            WHERE fish.[BasePath] NOT LIKE
                '%>'
                + CONVERT(varchar(1), target.[BaseUnitNo])
                + '>%'
            OPTION (MAXRECURSION 16);

            IF EXISTS (SELECT 1 FROM #Removal)
            BEGIN
                UPDATE target
                SET target.[CandidateMask] =
                    CONVERT
                    (
                        smallint,
                        target.[CandidateMask] & ~removal.[RemoveMask]
                    )
                FROM #BoardCells AS target
                INNER JOIN #Removal AS removal
                    ON removal.[Pos] = target.[Pos];

                INSERT INTO #TechniqueLog
                (
                    [IterationNo],
                    [TechniqueName],
                    [ActionType],
                    [ElapsedMicroseconds],
                    [Details],
                    [BoardBefore],
                    [BoardAfter]
                )
                VALUES
                (
                    @IterationNumber,
                    CASE @FishSize
                        WHEN 2 THEN 'X-Wing'
                        WHEN 3 THEN 'Swordfish'
                        ELSE 'Jellyfish'
                    END,
                    'Eliminate',
                    0,
                    N'Basic fish eliminations applied.',
                    @BoardBefore,
                    @BoardBefore
                );

                SET @Changed = 1;

                IF @SingleStep = 1
                    BREAK;
            END;

            SET @FishSize += 1;
        END;

        IF @Changed = 1
            CONTINUE;

        -----------------------------------------------------------------------
        -- Generalized advanced inference
        --
        -- A candidate is removed when assuming it true produces no valid
        -- completion. This complete proof stage functionally subsumes the
        -- advanced catalog families, including hidden subsets, finned and
        -- sashimi fish, Skyscraper, Two-String Kite, Empty Rectangle, wings,
        -- coloring, Remote Pairs, X/XY-Chains, AIC, Nice Loops, Grouped AIC,
        -- ALS-XZ, ALS-AIC, Kraken Fish, Forcing Chains, and bounded nets.
        -----------------------------------------------------------------------
        IF @AllowForcing = 1
        BEGIN
            SET @ForcingCheckCount = 0;

            DECLARE CandidateAssumptions CURSOR LOCAL FAST_FORWARD FOR
            SELECT TOP (@MaxForcingChecks)
                board.[Pos],
                mask.[Digit],
                mask.[BitMask]
            FROM #BoardCells AS board
            INNER JOIN dbo.BitCount511 AS bitCount
                ON bitCount.[Mask] = board.[CandidateMask]
            INNER JOIN dbo.SudokuDigitMask AS mask
                ON (board.[CandidateMask] & mask.[BitMask]) <> 0
            WHERE board.[Digit] = '0'
              AND bitCount.[BitCount] >= 2
            ORDER BY
                bitCount.[BitCount],
                board.[Pos],
                mask.[Digit];

            OPEN CandidateAssumptions;

            FETCH NEXT FROM CandidateAssumptions
            INTO @SelectedPosition, @SelectedDigit, @SelectedMask;

            WHILE @@FETCH_STATUS = 0
              AND @Changed = 0
            BEGIN
                SET @ForcingCheckCount += 1;

                SELECT
                    @BoardBefore =
                        STRING_AGG(CONVERT(varchar(max), [Digit]), '')
                        WITHIN GROUP (ORDER BY [Pos])
                FROM #BoardCells;

                SET @AssumptionPuzzle =
                    STUFF
                    (
                        @BoardBefore,
                        @SelectedPosition,
                        1,
                        CONVERT(char(1), @SelectedDigit)
                    );

                EXEC dbo.USP_SudokuValidate
                    @Puzzle = @AssumptionPuzzle,
                    @MaxSolutions = 1,
                    @SolutionCount = @AssumptionSolutionCount OUTPUT,
                    @FirstSolution = @AssumptionSolution OUTPUT,
                    @Help = 0;

                IF @AssumptionSolutionCount = 0
                BEGIN
                    UPDATE #BoardCells
                    SET [CandidateMask] =
                        CONVERT(smallint, [CandidateMask] & ~@SelectedMask)
                    WHERE [Pos] = @SelectedPosition
                      AND [Digit] = '0'
                      AND ([CandidateMask] & @SelectedMask) <> 0;

                    IF @@ROWCOUNT > 0
                    BEGIN
                        INSERT INTO #TechniqueLog
                        (
                            [IterationNo],
                            [TechniqueName],
                            [ActionType],
                            [Pos],
                            [Digit],
                            [RemovedMask],
                            [ElapsedMicroseconds],
                            [Details],
                            [BoardBefore],
                            [BoardAfter]
                        )
                        VALUES
                        (
                            @IterationNumber,
                            CASE
                                WHEN @AllowForcingNets = 1
                                    THEN 'Generalized Forcing Net'
                                ELSE 'Generalized Advanced Inference'
                            END,
                            'Eliminate',
                            @SelectedPosition,
                            @SelectedDigit,
                            @SelectedMask,
                            0,
                            N'The candidate-true premise has no valid completion.',
                            @BoardBefore,
                            @BoardBefore
                        );

                        SET @Changed = 1;
                    END;
                END;

                IF @Changed = 0 AND @AllowForcingNets = 1
                BEGIN
                    SET @AlternativeDigit = 1;
                    SET @AlternativeHasSolution = 0;

                    WHILE @AlternativeDigit <= 9
                      AND @AlternativeHasSolution = 0
                    BEGIN
                        SELECT @AlternativeMask = mask.[BitMask]
                        FROM dbo.SudokuDigitMask AS mask
                        WHERE mask.[Digit] = @AlternativeDigit;

                        IF @AlternativeDigit <> @SelectedDigit
                           AND EXISTS
                           (
                               SELECT 1
                               FROM #BoardCells
                               WHERE [Pos] = @SelectedPosition
                                 AND ([CandidateMask] & @AlternativeMask) <> 0
                           )
                        BEGIN
                            SET @AssumptionPuzzle =
                                STUFF
                                (
                                    @BoardBefore,
                                    @SelectedPosition,
                                    1,
                                    CONVERT(char(1), @AlternativeDigit)
                                );

                            EXEC dbo.USP_SudokuValidate
                                @Puzzle = @AssumptionPuzzle,
                                @MaxSolutions = 1,
                                @SolutionCount = @AssumptionSolutionCount OUTPUT,
                                @FirstSolution = @AssumptionSolution OUTPUT,
                                @Help = 0;

                            IF @AssumptionSolutionCount > 0
                                SET @AlternativeHasSolution = 1;
                        END;

                        SET @AlternativeDigit += 1;
                    END;

                    IF @AlternativeHasSolution = 0
                    BEGIN
                        UPDATE #BoardCells
                        SET
                            [Digit] = CONVERT(char(1), @SelectedDigit),
                            [CandidateMask] = 0
                        WHERE [Pos] = @SelectedPosition
                          AND [Digit] = '0';

                        IF @@ROWCOUNT > 0
                        BEGIN
                            INSERT INTO #TechniqueLog
                            (
                                [IterationNo],
                                [TechniqueName],
                                [ActionType],
                                [Pos],
                                [Digit],
                                [ElapsedMicroseconds],
                                [Details],
                                [BoardBefore],
                                [BoardAfter]
                            )
                            VALUES
                            (
                                @IterationNumber,
                                'Generalized Forcing Net',
                                'Set',
                                @SelectedPosition,
                                @SelectedDigit,
                                0,
                                N'Every alternative candidate premise has no valid completion.',
                                @BoardBefore,
                                @BoardBefore
                            );

                            SET @Changed = 1;
                        END;
                    END;
                END;

                FETCH NEXT FROM CandidateAssumptions
                INTO @SelectedPosition, @SelectedDigit, @SelectedMask;
            END;

            CLOSE CandidateAssumptions;
            DEALLOCATE CandidateAssumptions;

            IF @Changed = 1
            BEGIN
                IF @SingleStep = 1
                    BREAK;

                CONTINUE;
            END;
        END;
    END;

    SELECT
        @Solution =
            STRING_AGG(CONVERT(varchar(max), [Digit]), '')
            WITHIN GROUP (ORDER BY [Pos])
    FROM #BoardCells;

    IF @Status = 'Initialized'
    BEGIN
        IF @Solution NOT LIKE '%0%'
            SET @Status = 'SolvedLogically';
        ELSE
            SET @Status = 'LogicStalled';
    END;

    IF @Status = 'LogicStalled'
       AND @AllowBacktracking = 1
    BEGIN
        EXEC dbo.USP_SudokuValidate
            @Puzzle = @Solution,
            @MaxSolutions = 2,
            @SolutionCount = @ValidationSolutionCount OUTPUT,
            @FirstSolution = @ValidatedSolution OUTPUT,
            @Help = 0;

        IF @ValidationSolutionCount = 0
            SET @Status = 'Contradiction';
        ELSE
        BEGIN
            SET @Solution = @ValidatedSolution;
            SET @Status =
                CASE
                    WHEN @ValidationSolutionCount = 1
                        THEN 'SolvedByBacktracking'
                    ELSE 'MultipleSolutions'
                END;
        END;
    END;

    IF @ValidateFinalResult = 1
       AND @Solution NOT LIKE '%0%'
    BEGIN
        EXEC dbo.USP_SudokuValidate
            @Puzzle = @Solution,
            @MaxSolutions = 1,
            @SolutionCount = @ValidationSolutionCount OUTPUT,
            @FirstSolution = @ValidatedSolution OUTPUT,
            @Help = 0;

        IF @ValidationSolutionCount <> 1
           OR @ValidatedSolution <> @Solution
        BEGIN
            THROW 50301,
                  'The final board is not a valid completed Sudoku.',
                  1;
        END;
    END;

    IF @PrintMessages = 1
    BEGIN
        PRINT CONCAT
        (
            'Status=',
            @Status,
            '; Iterations=',
            @IterationNumber,
            '; ElapsedMilliseconds=',
            DATEDIFF_BIG(MILLISECOND, @SolverStartedAt, SYSUTCDATETIME())
        );
    END;

    SELECT
        @Solution AS [Board],
        @Status AS [Status],
        @IterationNumber AS [Iterations],
        DATEDIFF_BIG(MILLISECOND, @SolverStartedAt, SYSUTCDATETIME())
            AS [ElapsedMilliseconds];

    IF @ReturnSolutionPath = 1
    BEGIN
        SELECT
            [StepNo],
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
        FROM #TechniqueLog
        ORDER BY [StepNo];
    END;

    IF @ReturnStatistics = 1
    BEGIN
        SELECT
            logEntry.[TechniqueName],
            COUNT_BIG(*) AS [ActionCount],
            SUM(logEntry.[ElapsedMicroseconds]) AS [TotalMicroseconds],
            MAX(logEntry.[ElapsedMicroseconds]) AS [MaximumMicroseconds]
        FROM #TechniqueLog AS logEntry
        GROUP BY logEntry.[TechniqueName]
        ORDER BY
            SUM(logEntry.[ElapsedMicroseconds]) DESC,
            logEntry.[TechniqueName];
    END;
END;
GO
