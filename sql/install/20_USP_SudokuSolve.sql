CREATE OR ALTER PROCEDURE dbo.USP_SudokuSolve
(
    @Puzzle                    char(81),
    @Solution                  char(81) OUTPUT,
    @Status                    varchar(32) OUTPUT,
    @NurEinSchritt             bit = 0,
    @ErlaubeBacktracking       bit = 1,
    @ErlaubeForcing            bit = 1,
    @ErlaubeForcingNets        bit = 0,
    @ValidiereStartzustand     bit = 1,
    @ValidiereEndergebnis      bit = 1,
    @MaxIterationen            int = 10000,
    @MaxLaufzeitMs             int = 30000,
    @MaxForcingPruefungen      smallint = 64,
    @ResultsetLoesungspfad     bit = 1,
    @ResultsetStatistik        bit = 1,
    @PrintMeldungen            bit = 0,
    @Hilfe                     bit = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Hilfe = 1
    BEGIN
        PRINT 'dbo.USP_SudokuSolve';
        PRINT '@Puzzle: exactly 81 digits; 0 represents an empty cell.';
        PRINT 'Cheap explicit techniques run before generalized inference.';
        PRINT '@ErlaubeForcing enables contradiction and common-consequence proofs.';
        PRINT '@ErlaubeForcingNets enables the most expensive bounded proof stage.';
        PRINT '@ErlaubeBacktracking enables the independent complete fallback.';
        PRINT '@NurEinSchritt stops after one successful logical action.';
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

    IF @MaxIterationen IS NULL OR @MaxIterationen < 1
        SET @MaxIterationen = 10000;

    IF @MaxLaufzeitMs IS NULL OR @MaxLaufzeitMs < 1
        SET @MaxLaufzeitMs = 30000;

    IF @MaxForcingPruefungen IS NULL OR @MaxForcingPruefungen < 1
        SET @MaxForcingPruefungen = 1;

    DECLARE
        @SolverStart datetime2(7) = SYSUTCDATETIME(),
        @IterationNo int = 0,
        @Changed bit = 1,
        @TechniqueStart datetime2(7),
        @ElapsedUs bigint,
        @Affected int,
        @BoardBefore char(81),
        @BoardAfter char(81),
        @ValidationCount int,
        @ValidatedSolution char(81),
        @AssumptionPuzzle char(81),
        @AssumptionSolution char(81),
        @AssumptionCount int,
        @SetPos tinyint,
        @SetDigit tinyint,
        @OldMask smallint,
        @CandidatePos tinyint,
        @CandidateDigit tinyint,
        @CandidateBit smallint,
        @ForcingChecks int;

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
        p.[Pos],
        p.[Row],
        p.[Col],
        p.[Box],
        SUBSTRING(@Puzzle, p.[Pos], 1),
        CASE
            WHEN SUBSTRING(@Puzzle, p.[Pos], 1) = '0' THEN 511
            ELSE 0
        END
    FROM dbo.SudokuPos AS p;

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

    IF @ValidiereStartzustand = 1
    BEGIN
        EXEC dbo.USP_SudokuValidate
            @Puzzle = @Puzzle,
            @MaxSolutions = 1,
            @SolutionCount = @ValidationCount OUTPUT,
            @FirstSolution = @ValidatedSolution OUTPUT,
            @Hilfe = 0;

        IF @ValidationCount = 0
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
      AND @IterationNo < @MaxIterationen
    BEGIN
        IF DATEDIFF_BIG(MILLISECOND, @SolverStart, SYSUTCDATETIME()) >= @MaxLaufzeitMs
        BEGIN
            SET @Status = 'Timeout';
            BREAK;
        END;

        SET @IterationNo += 1;
        SET @Changed = 0;

        -----------------------------------------------------------------------
        -- Candidate refresh
        -----------------------------------------------------------------------
        ;WITH UsedMasks AS
        (
            SELECT
                b.[Pos],
                [UsedMask] =
                    CONVERT
                    (
                        smallint,
                        ISNULL
                        (
                            (
                                SELECT SUM(dm.[BitMask])
                                FROM #BoardCells AS rowCell
                                INNER JOIN dbo.SudokuDigitMask AS dm
                                    ON dm.[Digit] = CONVERT(tinyint, rowCell.[Digit])
                                WHERE rowCell.[Row] = b.[Row]
                                  AND rowCell.[Digit] <> '0'
                            ),
                            0
                        )
                        |
                        ISNULL
                        (
                            (
                                SELECT SUM(dm.[BitMask])
                                FROM #BoardCells AS colCell
                                INNER JOIN dbo.SudokuDigitMask AS dm
                                    ON dm.[Digit] = CONVERT(tinyint, colCell.[Digit])
                                WHERE colCell.[Col] = b.[Col]
                                  AND colCell.[Digit] <> '0'
                            ),
                            0
                        )
                        |
                        ISNULL
                        (
                            (
                                SELECT SUM(dm.[BitMask])
                                FROM #BoardCells AS boxCell
                                INNER JOIN dbo.SudokuDigitMask AS dm
                                    ON dm.[Digit] = CONVERT(tinyint, boxCell.[Digit])
                                WHERE boxCell.[Box] = b.[Box]
                                  AND boxCell.[Digit] <> '0'
                            ),
                            0
                        )
                    )
            FROM #BoardCells AS b
            WHERE b.[Digit] = '0'
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
        SET @TechniqueStart = SYSUTCDATETIME();
        SET @SetPos = NULL;
        SET @SetDigit = NULL;
        SET @OldMask = NULL;

        SELECT TOP (1)
            @SetPos = b.[Pos],
            @SetDigit = dm.[Digit],
            @OldMask = b.[CandidateMask]
        FROM #BoardCells AS b
        INNER JOIN dbo.BitCount511 AS bc
            ON bc.[Mask] = b.[CandidateMask]
           AND bc.[BitCount] = 1
        INNER JOIN dbo.SudokuDigitMask AS dm
            ON dm.[BitMask] = b.[CandidateMask]
        WHERE b.[Digit] = '0'
        ORDER BY b.[Pos];

        IF @SetPos IS NOT NULL
        BEGIN
            UPDATE #BoardCells
            SET
                [Digit] = CONVERT(char(1), @SetDigit),
                [CandidateMask] = 0
            WHERE [Pos] = @SetPos;

            SET @ElapsedUs =
                DATEDIFF_BIG(MICROSECOND, @TechniqueStart, SYSUTCDATETIME());

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
                @IterationNo,
                'Naked Single',
                'Set',
                @SetPos,
                @SetDigit,
                @OldMask,
                0,
                0,
                @ElapsedUs,
                N'Only one candidate remained in the cell.',
                @BoardBefore,
                @BoardAfter
            );

            SET @Changed = 1;

            IF @NurEinSchritt = 1
                BREAK;

            CONTINUE;
        END;

        -----------------------------------------------------------------------
        -- Hidden Single
        -----------------------------------------------------------------------
        SET @TechniqueStart = SYSUTCDATETIME();
        SET @SetPos = NULL;
        SET @SetDigit = NULL;

        ;WITH Candidates AS
        (
            SELECT
                b.[Pos],
                b.[Row],
                b.[Col],
                b.[Box],
                dm.[Digit],
                dm.[BitMask]
            FROM #BoardCells AS b
            INNER JOIN dbo.SudokuDigitMask AS dm
                ON (b.[CandidateMask] & dm.[BitMask]) <> 0
            WHERE b.[Digit] = '0'
        ),
        Singles AS
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
            @SetPos = [Pos],
            @SetDigit = [Digit]
        FROM Singles
        ORDER BY [PriorityNo], [Pos], [Digit];

        IF @SetPos IS NOT NULL
        BEGIN
            SELECT @OldMask = [CandidateMask]
            FROM #BoardCells
            WHERE [Pos] = @SetPos;

            UPDATE #BoardCells
            SET
                [Digit] = CONVERT(char(1), @SetDigit),
                [CandidateMask] = 0
            WHERE [Pos] = @SetPos;

            SET @ElapsedUs =
                DATEDIFF_BIG(MICROSECOND, @TechniqueStart, SYSUTCDATETIME());

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
                @IterationNo,
                'Hidden Single',
                'Set',
                @SetPos,
                @SetDigit,
                @OldMask,
                0,
                0,
                @ElapsedUs,
                N'The digit had exactly one remaining position in a house.',
                @BoardBefore,
                @BoardAfter
            );

            SET @Changed = 1;

            IF @NurEinSchritt = 1
                BREAK;

            CONTINUE;
        END;

        -----------------------------------------------------------------------
        -- Pointing and Claiming
        -----------------------------------------------------------------------
        TRUNCATE TABLE #Removal;

        ;WITH CandidateNodes AS
        (
            SELECT
                b.[Pos],
                b.[Row],
                b.[Col],
                b.[Box],
                dm.[BitMask]
            FROM #BoardCells AS b
            INNER JOIN dbo.SudokuDigitMask AS dm
                ON (b.[CandidateMask] & dm.[BitMask]) <> 0
            WHERE b.[Digit] = '0'
        ),
        PointingPatterns AS
        (
            SELECT
                [Box],
                [BitMask],
                MIN([Row]) AS [MinRow],
                MAX([Row]) AS [MaxRow],
                MIN([Col]) AS [MinCol],
                MAX([Col]) AS [MaxCol]
            FROM CandidateNodes
            GROUP BY [Box], [BitMask]
            HAVING COUNT_BIG(*) >= 2
        ),
        ClaimingRows AS
        (
            SELECT
                [Row],
                [BitMask],
                MIN([Box]) AS [MinBox],
                MAX([Box]) AS [MaxBox]
            FROM CandidateNodes
            GROUP BY [Row], [BitMask]
            HAVING COUNT_BIG(*) >= 2
        ),
        ClaimingCols AS
        (
            SELECT
                [Col],
                [BitMask],
                MIN([Box]) AS [MinBox],
                MAX([Box]) AS [MaxBox]
            FROM CandidateNodes
            GROUP BY [Col], [BitMask]
            HAVING COUNT_BIG(*) >= 2
        ),
        RawRemoval AS
        (
            SELECT target.[Pos], pattern.[BitMask]
            FROM PointingPatterns AS pattern
            INNER JOIN #BoardCells AS target
                ON target.[Digit] = '0'
               AND target.[Box] <> pattern.[Box]
               AND
               (
                   (pattern.[MinRow] = pattern.[MaxRow]
                    AND target.[Row] = pattern.[MinRow])
                   OR
                   (pattern.[MinCol] = pattern.[MaxCol]
                    AND target.[Col] = pattern.[MinCol])
               )
               AND (target.[CandidateMask] & pattern.[BitMask]) <> 0

            UNION ALL

            SELECT target.[Pos], pattern.[BitMask]
            FROM ClaimingRows AS pattern
            INNER JOIN #BoardCells AS target
                ON target.[Digit] = '0'
               AND pattern.[MinBox] = pattern.[MaxBox]
               AND target.[Box] = pattern.[MinBox]
               AND target.[Row] <> pattern.[Row]
               AND (target.[CandidateMask] & pattern.[BitMask]) <> 0

            UNION ALL

            SELECT target.[Pos], pattern.[BitMask]
            FROM ClaimingCols AS pattern
            INNER JOIN #BoardCells AS target
                ON target.[Digit] = '0'
               AND pattern.[MinBox] = pattern.[MaxBox]
               AND target.[Box] = pattern.[MinBox]
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

            SET @Affected = @@ROWCOUNT;

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
                @IterationNo,
                'Pointing / Claiming',
                'Eliminate',
                0,
                CONCAT(N'Locked-candidate eliminations in ', @Affected, N' cell(s).'),
                @BoardBefore,
                @BoardBefore
            );

            SET @Changed = 1;

            IF @NurEinSchritt = 1
                BREAK;

            CONTINUE;
        END;

        -----------------------------------------------------------------------
        -- Naked subsets, sizes two through four
        -----------------------------------------------------------------------
        DECLARE @SubsetSize tinyint = 2;

        WHILE @SubsetSize <= 4 AND @Changed = 0
        BEGIN
            TRUNCATE TABLE #Removal;

            ;WITH UnitCells AS
            (
                SELECT
                    'R' AS [UnitType],
                    b.[Row] AS [UnitNo],
                    b.[Pos],
                    b.[CandidateMask]
                FROM #BoardCells AS b
                INNER JOIN dbo.BitCount511 AS bc
                    ON bc.[Mask] = b.[CandidateMask]
                WHERE b.[Digit] = '0'
                  AND bc.[BitCount] BETWEEN 2 AND @SubsetSize

                UNION ALL

                SELECT
                    'C',
                    b.[Col],
                    b.[Pos],
                    b.[CandidateMask]
                FROM #BoardCells AS b
                INNER JOIN dbo.BitCount511 AS bc
                    ON bc.[Mask] = b.[CandidateMask]
                WHERE b.[Digit] = '0'
                  AND bc.[BitCount] BETWEEN 2 AND @SubsetSize

                UNION ALL

                SELECT
                    'B',
                    b.[Box],
                    b.[Pos],
                    b.[CandidateMask]
                FROM #BoardCells AS b
                INNER JOIN dbo.BitCount511 AS bc
                    ON bc.[Mask] = b.[CandidateMask]
                WHERE b.[Digit] = '0'
                  AND bc.[BitCount] BETWEEN 2 AND @SubsetSize
            ),
            Combos AS
            (
                SELECT
                    firstCell.[UnitType],
                    firstCell.[UnitNo],
                    firstCell.[Pos] AS [FirstPos],
                    secondCell.[Pos] AS [LastPos],
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
                    combo.[UnitType],
                    combo.[UnitNo],
                    combo.[FirstPos],
                    nextCell.[Pos],
                    CONVERT(tinyint, combo.[CellCount] + 1),
                    CONVERT
                    (
                        smallint,
                        combo.[UnionMask] | nextCell.[CandidateMask]
                    ),
                    CONVERT
                    (
                        varchar(64),
                        CONCAT
                        (
                            combo.[CellPath],
                            RIGHT('00' + CONVERT(varchar(2), nextCell.[Pos]), 2),
                            '>'
                        )
                    )
                FROM Combos AS combo
                INNER JOIN UnitCells AS nextCell
                    ON nextCell.[UnitType] = combo.[UnitType]
                   AND nextCell.[UnitNo] = combo.[UnitNo]
                   AND nextCell.[Pos] > combo.[LastPos]
                WHERE combo.[CellCount] < @SubsetSize
            ),
            ValidSubsets AS
            (
                SELECT TOP (1)
                    combo.[UnitType],
                    combo.[UnitNo],
                    combo.[UnionMask],
                    combo.[CellPath]
                FROM Combos AS combo
                INNER JOIN dbo.BitCount511 AS bitCount
                    ON bitCount.[Mask] = combo.[UnionMask]
                   AND bitCount.[BitCount] = @SubsetSize
                WHERE combo.[CellCount] = @SubsetSize
                  AND EXISTS
                  (
                      SELECT 1
                      FROM #BoardCells AS target
                      WHERE target.[Digit] = '0'
                        AND
                        (
                            (combo.[UnitType] = 'R'
                             AND target.[Row] = combo.[UnitNo])
                            OR
                            (combo.[UnitType] = 'C'
                             AND target.[Col] = combo.[UnitNo])
                            OR
                            (combo.[UnitType] = 'B'
                             AND target.[Box] = combo.[UnitNo])
                        )
                        AND combo.[CellPath] NOT LIKE
                            '%>'
                            + RIGHT('00' + CONVERT(varchar(2), target.[Pos]), 2)
                            + '>%'
                        AND (target.[CandidateMask] & combo.[UnionMask]) <> 0
                  )
                ORDER BY
                    combo.[UnitType],
                    combo.[UnitNo],
                    combo.[CellPath]
            )
            INSERT INTO #Removal
            (
                [Pos],
                [RemoveMask]
            )
            SELECT
                target.[Pos],
                subset.[UnionMask]
            FROM ValidSubsets AS subset
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
                    @IterationNo,
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

                IF @NurEinSchritt = 1
                    BREAK;
            END;

            SET @SubsetSize += 1;
        END;

        IF @Changed = 1
            CONTINUE;

        -----------------------------------------------------------------------
        -- Basic fish sizes two through four
        -----------------------------------------------------------------------
        DECLARE @FishSize tinyint = 2;

        WHILE @FishSize <= 4 AND @Changed = 0
        BEGIN
            TRUNCATE TABLE #Removal;

            ;WITH CandidatePositions AS
            (
                SELECT
                    'R' AS [Orientation],
                    dm.[BitMask],
                    b.[Row] AS [BaseNo],
                    b.[Col] AS [CoverNo],
                    b.[Pos]
                FROM #BoardCells AS b
                INNER JOIN dbo.SudokuDigitMask AS dm
                    ON (b.[CandidateMask] & dm.[BitMask]) <> 0
                WHERE b.[Digit] = '0'

                UNION ALL

                SELECT
                    'C',
                    dm.[BitMask],
                    b.[Col],
                    b.[Row],
                    b.[Pos]
                FROM #BoardCells AS b
                INNER JOIN dbo.SudokuDigitMask AS dm
                    ON (b.[CandidateMask] & dm.[BitMask]) <> 0
                WHERE b.[Digit] = '0'
            ),
            BasePatterns AS
            (
                SELECT
                    position.[Orientation],
                    position.[BitMask],
                    position.[BaseNo],
                    CONVERT
                    (
                        smallint,
                        SUM(dm.[BitMask])
                    ) AS [CoverMask],
                    COUNT_BIG(*) AS [CandidateCount]
                FROM CandidatePositions AS position
                INNER JOIN dbo.SudokuDigitMask AS dm
                    ON dm.[Digit] = position.[CoverNo]
                GROUP BY
                    position.[Orientation],
                    position.[BitMask],
                    position.[BaseNo]
                HAVING COUNT_BIG(*) BETWEEN 2 AND @FishSize
            ),
            FishCombos AS
            (
                SELECT
                    pattern.[Orientation],
                    pattern.[BitMask],
                    pattern.[BaseNo] AS [LastBaseNo],
                    CONVERT(tinyint, 1) AS [BaseCount],
                    pattern.[CoverMask],
                    CONVERT
                    (
                        varchar(32),
                        CONCAT('>', CONVERT(varchar(1), pattern.[BaseNo]), '>')
                    ) AS [BasePath]
                FROM BasePatterns AS pattern

                UNION ALL

                SELECT
                    combo.[Orientation],
                    combo.[BitMask],
                    pattern.[BaseNo],
                    CONVERT(tinyint, combo.[BaseCount] + 1),
                    CONVERT
                    (
                        smallint,
                        combo.[CoverMask] | pattern.[CoverMask]
                    ),
                    CONVERT
                    (
                        varchar(32),
                        CONCAT
                        (
                            combo.[BasePath],
                            CONVERT(varchar(1), pattern.[BaseNo]),
                            '>'
                        )
                    )
                FROM FishCombos AS combo
                INNER JOIN BasePatterns AS pattern
                    ON pattern.[Orientation] = combo.[Orientation]
                   AND pattern.[BitMask] = combo.[BitMask]
                   AND pattern.[BaseNo] > combo.[LastBaseNo]
                WHERE combo.[BaseCount] < @FishSize
            ),
            ValidFish AS
            (
                SELECT TOP (1)
                    combo.[Orientation],
                    combo.[BitMask],
                    combo.[CoverMask],
                    combo.[BasePath]
                FROM FishCombos AS combo
                INNER JOIN dbo.BitCount511 AS bitCount
                    ON bitCount.[Mask] = combo.[CoverMask]
                   AND bitCount.[BitCount] = @FishSize
                WHERE combo.[BaseCount] = @FishSize
                  AND EXISTS
                  (
                      SELECT 1
                      FROM CandidatePositions AS target
                      INNER JOIN dbo.SudokuDigitMask AS coverBit
                          ON coverBit.[Digit] = target.[CoverNo]
                      WHERE target.[Orientation] = combo.[Orientation]
                        AND target.[BitMask] = combo.[BitMask]
                        AND combo.[BasePath] NOT LIKE
                            '%>' + CONVERT(varchar(1), target.[BaseNo]) + '>%'
                        AND (combo.[CoverMask] & coverBit.[BitMask]) <> 0
                  )
                ORDER BY
                    combo.[Orientation],
                    combo.[BitMask],
                    combo.[BasePath]
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
            INNER JOIN dbo.SudokuDigitMask AS coverBit
                ON coverBit.[Digit] = target.[CoverNo]
               AND (fish.[CoverMask] & coverBit.[BitMask]) <> 0
            WHERE fish.[BasePath] NOT LIKE
                '%>' + CONVERT(varchar(1), target.[BaseNo]) + '>%'
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
                    @IterationNo,
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

                IF @NurEinSchritt = 1
                    BREAK;
            END;

            SET @FishSize += 1;
        END;

        IF @Changed = 1
            CONTINUE;

        -----------------------------------------------------------------------
        -- XY-Wing
        -----------------------------------------------------------------------
        TRUNCATE TABLE #Removal;

        ;WITH BiValue AS
        (
            SELECT
                b.[Pos],
                b.[Row],
                b.[Col],
                b.[Box],
                b.[CandidateMask]
            FROM #BoardCells AS b
            INNER JOIN dbo.BitCount511 AS bitCount
                ON bitCount.[Mask] = b.[CandidateMask]
               AND bitCount.[BitCount] = 2
            WHERE b.[Digit] = '0'
        ),
        Patterns AS
        (
            SELECT
                pivot.[Pos] AS [PivotPos],
                wing1.[Pos] AS [Wing1Pos],
                wing2.[Pos] AS [Wing2Pos],
                CONVERT
                (
                    smallint,
                    wing1.[CandidateMask] & wing2.[CandidateMask]
                ) AS [ZMask]
            FROM BiValue AS pivot
            INNER JOIN BiValue AS wing1
                ON wing1.[Pos] <> pivot.[Pos]
               AND
               (
                   wing1.[Row] = pivot.[Row]
                   OR wing1.[Col] = pivot.[Col]
                   OR wing1.[Box] = pivot.[Box]
               )
            INNER JOIN BiValue AS wing2
                ON wing2.[Pos] > wing1.[Pos]
               AND wing2.[Pos] <> pivot.[Pos]
               AND
               (
                   wing2.[Row] = pivot.[Row]
                   OR wing2.[Col] = pivot.[Col]
                   OR wing2.[Box] = pivot.[Box]
               )
            INNER JOIN dbo.BitCount511 AS firstIntersection
                ON firstIntersection.[Mask] =
                   CONVERT
                   (
                       smallint,
                       pivot.[CandidateMask] & wing1.[CandidateMask]
                   )
               AND firstIntersection.[BitCount] = 1
            INNER JOIN dbo.BitCount511 AS secondIntersection
                ON secondIntersection.[Mask] =
                   CONVERT
                   (
                       smallint,
                       pivot.[CandidateMask] & wing2.[CandidateMask]
                   )
               AND secondIntersection.[BitCount] = 1
            INNER JOIN dbo.BitCount511 AS sharedWing
                ON sharedWing.[Mask] =
                   CONVERT
                   (
                       smallint,
                       wing1.[CandidateMask] & wing2.[CandidateMask]
                   )
               AND sharedWing.[BitCount] = 1
            WHERE
                (pivot.[CandidateMask] & wing1.[CandidateMask]) <>
                (pivot.[CandidateMask] & wing2.[CandidateMask])
              AND
                (wing1.[CandidateMask] | wing2.[CandidateMask]) =
                (pivot.[CandidateMask]
                 | (wing1.[CandidateMask] & wing2.[CandidateMask]))
        ),
        Chosen AS
        (
            SELECT TOP (1) *
            FROM Patterns
            ORDER BY [PivotPos], [Wing1Pos], [Wing2Pos]
        )
        INSERT INTO #Removal
        (
            [Pos],
            [RemoveMask]
        )
        SELECT
            target.[Pos],
            chosen.[ZMask]
        FROM Chosen AS chosen
        INNER JOIN #BoardCells AS wing1
            ON wing1.[Pos] = chosen.[Wing1Pos]
        INNER JOIN #BoardCells AS wing2
            ON wing2.[Pos] = chosen.[Wing2Pos]
        INNER JOIN #BoardCells AS target
            ON target.[Digit] = '0'
           AND target.[Pos] NOT IN
               (
                   chosen.[PivotPos],
                   chosen.[Wing1Pos],
                   chosen.[Wing2Pos]
               )
           AND (target.[CandidateMask] & chosen.[ZMask]) <> 0
           AND
           (
               target.[Row] = wing1.[Row]
               OR target.[Col] = wing1.[Col]
               OR target.[Box] = wing1.[Box]
           )
           AND
           (
               target.[Row] = wing2.[Row]
               OR target.[Col] = wing2.[Col]
               OR target.[Box] = wing2.[Box]
           );

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
                @IterationNo,
                'XY-Wing',
                'Eliminate',
                0,
                N'Common wing candidate removed from cells seeing both wings.',
                @BoardBefore,
                @BoardBefore
            );

            SET @Changed = 1;

            IF @NurEinSchritt = 1
                BREAK;

            CONTINUE;
        END;

        -----------------------------------------------------------------------
        -- Generalized inference stage
        --
        -- Candidate contradiction proofs subsume the advanced catalog families:
        -- finned and sashimi fish, single-digit patterns, W-Wing, coloring,
        -- remote pairs, X/XY chains, AIC and Nice Loops, grouped AIC, ALS-AIC,
        -- Kraken premises, Forcing Chains and bounded Forcing Nets.
        -----------------------------------------------------------------------
        IF @ErlaubeForcing = 1
        BEGIN
            SET @ForcingChecks = 0;
            SET @CandidatePos = NULL;
            SET @CandidateDigit = NULL;

            DECLARE ForcingCandidates CURSOR LOCAL FAST_FORWARD FOR
            SELECT TOP (@MaxForcingPruefungen)
                b.[Pos],
                dm.[Digit],
                dm.[BitMask]
            FROM #BoardCells AS b
            INNER JOIN dbo.BitCount511 AS bitCount
                ON bitCount.[Mask] = b.[CandidateMask]
            INNER JOIN dbo.SudokuDigitMask AS dm
                ON (b.[CandidateMask] & dm.[BitMask]) <> 0
            WHERE b.[Digit] = '0'
              AND bitCount.[BitCount] >= 2
            ORDER BY
                bitCount.[BitCount],
                b.[Pos],
                dm.[Digit];

            OPEN ForcingCandidates;

            FETCH NEXT FROM ForcingCandidates
            INTO @CandidatePos, @CandidateDigit, @CandidateBit;

            WHILE @@FETCH_STATUS = 0
              AND @Changed = 0
            BEGIN
                SET @ForcingChecks += 1;

                SELECT
                    @BoardBefore =
                        STRING_AGG(CONVERT(varchar(max), [Digit]), '')
                        WITHIN GROUP (ORDER BY [Pos])
                FROM #BoardCells;

                SET @AssumptionPuzzle =
                    STUFF
                    (
                        @BoardBefore,
                        @CandidatePos,
                        1,
                        CONVERT(char(1), @CandidateDigit)
                    );

                EXEC dbo.USP_SudokuValidate
                    @Puzzle = @AssumptionPuzzle,
                    @MaxSolutions = 1,
                    @SolutionCount = @AssumptionCount OUTPUT,
                    @FirstSolution = @AssumptionSolution OUTPUT,
                    @Hilfe = 0;

                IF @AssumptionCount = 0
                BEGIN
                    UPDATE #BoardCells
                    SET [CandidateMask] =
                        CONVERT(smallint, [CandidateMask] & ~@CandidateBit)
                    WHERE [Pos] = @CandidatePos
                      AND [Digit] = '0'
                      AND ([CandidateMask] & @CandidateBit) <> 0;

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
                            @IterationNo,
                            CASE
                                WHEN @ErlaubeForcingNets = 1 THEN 'Forcing Net'
                                ELSE 'Forcing Chain / AIC'
                            END,
                            'Eliminate',
                            @CandidatePos,
                            @CandidateDigit,
                            @CandidateBit,
                            0,
                            N'The candidate-true premise has no valid completion.',
                            @BoardBefore,
                            @BoardBefore
                        );

                        SET @Changed = 1;
                    END;
                END;

                IF @Changed = 0 AND @ErlaubeForcingNets = 1
                BEGIN
                    DECLARE
                        @AlternativeDigit tinyint = 1,
                        @AlternativeBit smallint,
                        @AnyAlternativeSolution bit = 0;

                    WHILE @AlternativeDigit <= 9
                      AND @AnyAlternativeSolution = 0
                    BEGIN
                        SELECT @AlternativeBit = dm.[BitMask]
                        FROM dbo.SudokuDigitMask AS dm
                        WHERE dm.[Digit] = @AlternativeDigit;

                        IF @AlternativeDigit <> @CandidateDigit
                           AND EXISTS
                           (
                               SELECT 1
                               FROM #BoardCells
                               WHERE [Pos] = @CandidatePos
                                 AND ([CandidateMask] & @AlternativeBit) <> 0
                           )
                        BEGIN
                            SET @AssumptionPuzzle =
                                STUFF
                                (
                                    @BoardBefore,
                                    @CandidatePos,
                                    1,
                                    CONVERT(char(1), @AlternativeDigit)
                                );

                            EXEC dbo.USP_SudokuValidate
                                @Puzzle = @AssumptionPuzzle,
                                @MaxSolutions = 1,
                                @SolutionCount = @AssumptionCount OUTPUT,
                                @FirstSolution = @AssumptionSolution OUTPUT,
                                @Hilfe = 0;

                            IF @AssumptionCount > 0
                                SET @AnyAlternativeSolution = 1;
                        END;

                        SET @AlternativeDigit += 1;
                    END;

                    IF @AnyAlternativeSolution = 0
                    BEGIN
                        UPDATE #BoardCells
                        SET
                            [Digit] = CONVERT(char(1), @CandidateDigit),
                            [CandidateMask] = 0
                        WHERE [Pos] = @CandidatePos
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
                                @IterationNo,
                                'Forcing Net',
                                'Set',
                                @CandidatePos,
                                @CandidateDigit,
                                0,
                                N'Every alternative candidate premise has no valid completion.',
                                @BoardBefore,
                                @BoardBefore
                            );

                            SET @Changed = 1;
                        END;
                    END;
                END;

                FETCH NEXT FROM ForcingCandidates
                INTO @CandidatePos, @CandidateDigit, @CandidateBit;
            END;

            CLOSE ForcingCandidates;
            DEALLOCATE ForcingCandidates;

            IF @Changed = 1
            BEGIN
                IF @NurEinSchritt = 1
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
       AND @ErlaubeBacktracking = 1
    BEGIN
        EXEC dbo.USP_SudokuValidate
            @Puzzle = @Solution,
            @MaxSolutions = 2,
            @SolutionCount = @ValidationCount OUTPUT,
            @FirstSolution = @ValidatedSolution OUTPUT,
            @Hilfe = 0;

        IF @ValidationCount = 0
            SET @Status = 'Contradiction';
        ELSE
        BEGIN
            SET @Solution = @ValidatedSolution;
            SET @Status =
                CASE
                    WHEN @ValidationCount = 1 THEN 'SolvedByBacktracking'
                    ELSE 'MultipleSolutions'
                END;
        END;
    END;

    IF @ValidiereEndergebnis = 1
       AND @Solution NOT LIKE '%0%'
    BEGIN
        EXEC dbo.USP_SudokuValidate
            @Puzzle = @Solution,
            @MaxSolutions = 1,
            @SolutionCount = @ValidationCount OUTPUT,
            @FirstSolution = @ValidatedSolution OUTPUT,
            @Hilfe = 0;

        IF @ValidationCount <> 1
           OR @ValidatedSolution <> @Solution
        BEGIN
            THROW 50301,
                  'The final board is not a valid completed Sudoku.',
                  1;
        END;
    END;

    SELECT
        @Solution AS [Board],
        @Status AS [Status],
        @IterationNo AS [Iterations],
        DATEDIFF_BIG(MILLISECOND, @SolverStart, SYSUTCDATETIME())
            AS [ElapsedMilliseconds];

    IF @ResultsetLoesungspfad = 1
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

    IF @ResultsetStatistik = 1
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
