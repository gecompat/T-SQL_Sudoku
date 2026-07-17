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
        PRINT '@CandidateState: optional complete 81-row candidate state for deterministic unit tests.';
        PRINT '@UseCandidateState: use the supplied candidate masks instead of deriving them from @Puzzle.';
        RETURN;
    END;

    IF @UseCandidateState = 0
       AND
       (
           @Puzzle IS NULL
           OR LEN(@Puzzle) <> 81
           OR @Puzzle LIKE '%[^0-9]%'
       )
    BEGIN
        THROW 50500,
              'Puzzle must contain exactly 81 digits from 0 through 9.',
              1;
    END;

    IF @UseCandidateState = 1
       AND
       (
           (SELECT COUNT_BIG(*) FROM @CandidateState) <> 81
           OR EXISTS
              (
                  SELECT 1
                  FROM @CandidateState
                  WHERE [CandidateMask] NOT BETWEEN 1 AND 511
              )
       )
    BEGIN
        THROW 50501,
              'Candidate state must contain exactly 81 positions with masks from 1 through 511.',
              1;
    END;

    CREATE TABLE #BoardCells
    (
        [Pos] tinyint NOT NULL PRIMARY KEY CLUSTERED,
        [Row] tinyint NOT NULL,
        [Col] tinyint NOT NULL,
        [Box] tinyint NOT NULL,
        [Digit] char(1) NOT NULL,
        [CandidateMask] smallint NOT NULL
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
        CASE
            WHEN @UseCandidateState = 1
                THEN '0'
            ELSE SUBSTRING(@Puzzle, position.[Pos], 1)
        END,
        CASE
            WHEN @UseCandidateState = 1
                THEN candidate.[CandidateMask]
            WHEN SUBSTRING(@Puzzle, position.[Pos], 1) = '0'
                THEN 511
            ELSE 0
        END
    FROM dbo.SudokuPos AS position
    LEFT JOIN @CandidateState AS candidate
        ON candidate.[Pos] = position.[Pos];

    IF @UseCandidateState = 0
    BEGIN
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
    END;

    CREATE TABLE #Deduction
    (
        [SequenceNo] int IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
        [TechniqueName] varchar(64) NOT NULL,
        [ActionType] varchar(16) NOT NULL,
        [Pos] tinyint NOT NULL,
        [Digit] tinyint NULL,
        [OldCandidateMask] smallint NOT NULL,
        [NewCandidateMask] smallint NOT NULL,
        [RemovedMask] smallint NOT NULL,
        [Evidence] nvarchar(2000) NOT NULL
    );

    ---------------------------------------------------------------------------
    -- Naked Single
    ---------------------------------------------------------------------------
    INSERT INTO #Deduction
    (
        [TechniqueName], [ActionType], [Pos], [Digit],
        [OldCandidateMask], [NewCandidateMask], [RemovedMask], [Evidence]
    )
    SELECT TOP (1)
        'Naked Single',
        'Set',
        board.[Pos],
        mask.[Digit],
        board.[CandidateMask],
        0,
        0,
        N'Only one candidate remains in the cell.'
    FROM #BoardCells AS board
    INNER JOIN dbo.BitCount511 AS bitCount
        ON bitCount.[Mask] = board.[CandidateMask]
       AND bitCount.[BitCount] = 1
    INNER JOIN dbo.SudokuDigitMask AS mask
        ON mask.[BitMask] = board.[CandidateMask]
    WHERE board.[Digit] = '0'
    ORDER BY board.[Pos];

    IF EXISTS (SELECT 1 FROM #Deduction)
        GOTO ReturnResult;

    ---------------------------------------------------------------------------
    -- Hidden Single
    ---------------------------------------------------------------------------
    ;WITH CandidateNodes AS
    (
        SELECT
            board.[Pos],
            board.[Row],
            board.[Col],
            board.[Box],
            board.[CandidateMask],
            mask.[Digit]
        FROM #BoardCells AS board
        INNER JOIN dbo.SudokuDigitMask AS mask
            ON (board.[CandidateMask] & mask.[BitMask]) <> 0
        WHERE board.[Digit] = '0'
    ),
    HiddenSingles AS
    (
        SELECT MIN([Pos]) AS [Pos], [Digit], 1 AS [PriorityNo]
        FROM CandidateNodes
        GROUP BY [Row], [Digit]
        HAVING COUNT_BIG(*) = 1

        UNION ALL

        SELECT MIN([Pos]), [Digit], 2
        FROM CandidateNodes
        GROUP BY [Col], [Digit]
        HAVING COUNT_BIG(*) = 1

        UNION ALL

        SELECT MIN([Pos]), [Digit], 3
        FROM CandidateNodes
        GROUP BY [Box], [Digit]
        HAVING COUNT_BIG(*) = 1
    )
    INSERT INTO #Deduction
    (
        [TechniqueName], [ActionType], [Pos], [Digit],
        [OldCandidateMask], [NewCandidateMask], [RemovedMask], [Evidence]
    )
    SELECT TOP (1)
        'Hidden Single',
        'Set',
        hidden.[Pos],
        hidden.[Digit],
        board.[CandidateMask],
        0,
        0,
        N'The digit has exactly one remaining position in a row, column, or box.'
    FROM HiddenSingles AS hidden
    INNER JOIN #BoardCells AS board
        ON board.[Pos] = hidden.[Pos]
    ORDER BY hidden.[PriorityNo], hidden.[Pos], hidden.[Digit];

    IF EXISTS (SELECT 1 FROM #Deduction)
        GOTO ReturnResult;

    ---------------------------------------------------------------------------
    -- Pointing and Claiming
    ---------------------------------------------------------------------------
    CREATE TABLE #Removal
    (
        [TechniqueName] varchar(64) NOT NULL,
        [Pos] tinyint NOT NULL,
        [RemoveMask] smallint NOT NULL,
        PRIMARY KEY CLUSTERED ([TechniqueName], [Pos])
    );

    ;WITH CandidateNodes AS
    (
        SELECT
            board.[Pos], board.[Row], board.[Col], board.[Box], mask.[BitMask]
        FROM #BoardCells AS board
        INNER JOIN dbo.SudokuDigitMask AS mask
            ON (board.[CandidateMask] & mask.[BitMask]) <> 0
        WHERE board.[Digit] = '0'
    ),
    BoxPatterns AS
    (
        SELECT
            [Box], [BitMask],
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
            [Row], [BitMask],
            MIN([Box]) AS [MinimumBox],
            MAX([Box]) AS [MaximumBox]
        FROM CandidateNodes
        GROUP BY [Row], [BitMask]
        HAVING COUNT_BIG(*) >= 2
    ),
    ColumnPatterns AS
    (
        SELECT
            [Col], [BitMask],
            MIN([Box]) AS [MinimumBox],
            MAX([Box]) AS [MaximumBox]
        FROM CandidateNodes
        GROUP BY [Col], [BitMask]
        HAVING COUNT_BIG(*) >= 2
    ),
    RawRemoval AS
    (
        SELECT 'Pointing' AS [TechniqueName], target.[Pos], pattern.[BitMask]
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

        SELECT 'Claiming', target.[Pos], pattern.[BitMask]
        FROM RowPatterns AS pattern
        INNER JOIN #BoardCells AS target
            ON target.[Digit] = '0'
           AND pattern.[MinimumBox] = pattern.[MaximumBox]
           AND target.[Box] = pattern.[MinimumBox]
           AND target.[Row] <> pattern.[Row]
           AND (target.[CandidateMask] & pattern.[BitMask]) <> 0

        UNION ALL

        SELECT 'Claiming', target.[Pos], pattern.[BitMask]
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
        [TechniqueName], [Pos], [RemoveMask]
    )
    SELECT
        raw.[TechniqueName],
        raw.[Pos],
        CONVERT(smallint, SUM(DISTINCT raw.[BitMask]))
    FROM RawRemoval AS raw
    GROUP BY raw.[TechniqueName], raw.[Pos];

    DECLARE @SelectedTechnique varchar(64);

    SELECT TOP (1)
        @SelectedTechnique = removal.[TechniqueName]
    FROM #Removal AS removal
    ORDER BY
        CASE removal.[TechniqueName]
            WHEN 'Pointing' THEN 1
            ELSE 2
        END,
        removal.[Pos];

    IF @SelectedTechnique IS NOT NULL
    BEGIN
        INSERT INTO #Deduction
        (
            [TechniqueName], [ActionType], [Pos], [Digit],
            [OldCandidateMask], [NewCandidateMask], [RemovedMask], [Evidence]
        )
        SELECT
            removal.[TechniqueName],
            'Eliminate',
            removal.[Pos],
            NULL,
            board.[CandidateMask],
            CONVERT(smallint, board.[CandidateMask] & ~removal.[RemoveMask]),
            CONVERT(smallint, board.[CandidateMask] & removal.[RemoveMask]),
            CASE removal.[TechniqueName]
                WHEN 'Pointing'
                    THEN N'A box candidate is restricted to one row or column.'
                ELSE N'A row or column candidate is restricted to one box.'
            END
        FROM #Removal AS removal
        INNER JOIN #BoardCells AS board
            ON board.[Pos] = removal.[Pos]
        WHERE removal.[TechniqueName] = @SelectedTechnique
          AND (board.[CandidateMask] & removal.[RemoveMask]) <> 0
        ORDER BY removal.[Pos];

        GOTO ReturnResult;
    END;

    ---------------------------------------------------------------------------
    -- Naked Pair, Triple, and Quad
    ---------------------------------------------------------------------------
    DECLARE
        @SubsetSize tinyint = 2,
        @UnitType char(1),
        @UnitNo tinyint,
        @UnionMask smallint,
        @Pos1 tinyint,
        @Pos2 tinyint,
        @Pos3 tinyint,
        @Pos4 tinyint;

    WHILE @SubsetSize <= 4
    BEGIN
        SET @UnitType = NULL;
        SET @UnitNo = NULL;
        SET @UnionMask = NULL;
        SET @Pos1 = NULL;
        SET @Pos2 = NULL;
        SET @Pos3 = NULL;
        SET @Pos4 = NULL;

        ;WITH UnitCells AS
        (
            SELECT 'R' AS [UnitType], [Row] AS [UnitNo], [Pos], [CandidateMask]
            FROM #BoardCells
            WHERE [Digit] = '0'

            UNION ALL

            SELECT 'C', [Col], [Pos], [CandidateMask]
            FROM #BoardCells
            WHERE [Digit] = '0'

            UNION ALL

            SELECT 'B', [Box], [Pos], [CandidateMask]
            FROM #BoardCells
            WHERE [Digit] = '0'
        ),
        CandidateSubsets AS
        (
            SELECT
                firstCell.[UnitType],
                firstCell.[UnitNo],
                firstCell.[Pos] AS [Pos1],
                secondCell.[Pos] AS [Pos2],
                CONVERT(tinyint, NULL) AS [Pos3],
                CONVERT(tinyint, NULL) AS [Pos4],
                CONVERT(smallint, firstCell.[CandidateMask] | secondCell.[CandidateMask]) AS [UnionMask],
                CONVERT(tinyint, 2) AS [CellCount]
            FROM UnitCells AS firstCell
            INNER JOIN UnitCells AS secondCell
                ON secondCell.[UnitType] = firstCell.[UnitType]
               AND secondCell.[UnitNo] = firstCell.[UnitNo]
               AND secondCell.[Pos] > firstCell.[Pos]

            UNION ALL

            SELECT
                firstCell.[UnitType],
                firstCell.[UnitNo],
                firstCell.[Pos],
                secondCell.[Pos],
                thirdCell.[Pos],
                NULL,
                CONVERT
                (
                    smallint,
                    firstCell.[CandidateMask]
                    | secondCell.[CandidateMask]
                    | thirdCell.[CandidateMask]
                ),
                3
            FROM UnitCells AS firstCell
            INNER JOIN UnitCells AS secondCell
                ON secondCell.[UnitType] = firstCell.[UnitType]
               AND secondCell.[UnitNo] = firstCell.[UnitNo]
               AND secondCell.[Pos] > firstCell.[Pos]
            INNER JOIN UnitCells AS thirdCell
                ON thirdCell.[UnitType] = firstCell.[UnitType]
               AND thirdCell.[UnitNo] = firstCell.[UnitNo]
               AND thirdCell.[Pos] > secondCell.[Pos]

            UNION ALL

            SELECT
                firstCell.[UnitType],
                firstCell.[UnitNo],
                firstCell.[Pos],
                secondCell.[Pos],
                thirdCell.[Pos],
                fourthCell.[Pos],
                CONVERT
                (
                    smallint,
                    firstCell.[CandidateMask]
                    | secondCell.[CandidateMask]
                    | thirdCell.[CandidateMask]
                    | fourthCell.[CandidateMask]
                ),
                4
            FROM UnitCells AS firstCell
            INNER JOIN UnitCells AS secondCell
                ON secondCell.[UnitType] = firstCell.[UnitType]
               AND secondCell.[UnitNo] = firstCell.[UnitNo]
               AND secondCell.[Pos] > firstCell.[Pos]
            INNER JOIN UnitCells AS thirdCell
                ON thirdCell.[UnitType] = firstCell.[UnitType]
               AND thirdCell.[UnitNo] = firstCell.[UnitNo]
               AND thirdCell.[Pos] > secondCell.[Pos]
            INNER JOIN UnitCells AS fourthCell
                ON fourthCell.[UnitType] = firstCell.[UnitType]
               AND fourthCell.[UnitNo] = firstCell.[UnitNo]
               AND fourthCell.[Pos] > thirdCell.[Pos]
        )
        SELECT TOP (1)
            @UnitType = subset.[UnitType],
            @UnitNo = subset.[UnitNo],
            @Pos1 = subset.[Pos1],
            @Pos2 = subset.[Pos2],
            @Pos3 = subset.[Pos3],
            @Pos4 = subset.[Pos4],
            @UnionMask = subset.[UnionMask]
        FROM CandidateSubsets AS subset
        INNER JOIN dbo.BitCount511 AS bitCount
            ON bitCount.[Mask] = subset.[UnionMask]
           AND bitCount.[BitCount] = @SubsetSize
        WHERE subset.[CellCount] = @SubsetSize
          AND EXISTS
          (
              SELECT 1
              FROM #BoardCells AS target
              WHERE target.[Digit] = '0'
                AND
                (
                    (@UnitType IS NULL AND 1 = 1)
                    OR 1 = 1
                )
                AND
                (
                    (subset.[UnitType] = 'R' AND target.[Row] = subset.[UnitNo])
                    OR
                    (subset.[UnitType] = 'C' AND target.[Col] = subset.[UnitNo])
                    OR
                    (subset.[UnitType] = 'B' AND target.[Box] = subset.[UnitNo])
                )
                AND target.[Pos] NOT IN
                    (
                        subset.[Pos1],
                        subset.[Pos2],
                        ISNULL(subset.[Pos3], 0),
                        ISNULL(subset.[Pos4], 0)
                    )
                AND (target.[CandidateMask] & subset.[UnionMask]) <> 0
          )
        ORDER BY subset.[UnitType], subset.[UnitNo], subset.[Pos1], subset.[Pos2], subset.[Pos3], subset.[Pos4];

        IF @UnionMask IS NOT NULL
        BEGIN
            INSERT INTO #Deduction
            (
                [TechniqueName], [ActionType], [Pos], [Digit],
                [OldCandidateMask], [NewCandidateMask], [RemovedMask], [Evidence]
            )
            SELECT
                CASE @SubsetSize
                    WHEN 2 THEN 'Naked Pair'
                    WHEN 3 THEN 'Naked Triple'
                    ELSE 'Naked Quad'
                END,
                'Eliminate',
                target.[Pos],
                NULL,
                target.[CandidateMask],
                CONVERT(smallint, target.[CandidateMask] & ~@UnionMask),
                CONVERT(smallint, target.[CandidateMask] & @UnionMask),
                N'The selected cells contain exactly the same number of combined candidates.'
            FROM #BoardCells AS target
            WHERE target.[Digit] = '0'
              AND
              (
                  (@UnitType = 'R' AND target.[Row] = @UnitNo)
                  OR
                  (@UnitType = 'C' AND target.[Col] = @UnitNo)
                  OR
                  (@UnitType = 'B' AND target.[Box] = @UnitNo)
              )
              AND target.[Pos] NOT IN
                  (
                      @Pos1,
                      @Pos2,
                      ISNULL(@Pos3, 0),
                      ISNULL(@Pos4, 0)
                  )
              AND (target.[CandidateMask] & @UnionMask) <> 0
            ORDER BY target.[Pos];

            GOTO ReturnResult;
        END;

        SET @SubsetSize += 1;
    END;

    ---------------------------------------------------------------------------
    -- X-Wing, Swordfish, and Jellyfish
    ---------------------------------------------------------------------------
    DECLARE
        @FishSize tinyint = 2,
        @Orientation char(1),
        @FishDigitMask smallint,
        @CoverMask smallint,
        @Base1 tinyint,
        @Base2 tinyint,
        @Base3 tinyint,
        @Base4 tinyint;

    WHILE @FishSize <= 4
    BEGIN
        SET @Orientation = NULL;
        SET @FishDigitMask = NULL;
        SET @CoverMask = NULL;
        SET @Base1 = NULL;
        SET @Base2 = NULL;
        SET @Base3 = NULL;
        SET @Base4 = NULL;

        ;WITH CandidatePositions AS
        (
            SELECT
                'R' AS [Orientation],
                mask.[BitMask],
                board.[Row] AS [BaseUnitNo],
                board.[Col] AS [CoverUnitNo]
            FROM #BoardCells AS board
            INNER JOIN dbo.SudokuDigitMask AS mask
                ON (board.[CandidateMask] & mask.[BitMask]) <> 0
            WHERE board.[Digit] = '0'

            UNION ALL

            SELECT
                'C',
                mask.[BitMask],
                board.[Col],
                board.[Row]
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
                CONVERT(smallint, SUM(DISTINCT coverMask.[BitMask])) AS [CoverMask]
            FROM CandidatePositions AS position
            INNER JOIN dbo.SudokuDigitMask AS coverMask
                ON coverMask.[Digit] = position.[CoverUnitNo]
            GROUP BY
                position.[Orientation],
                position.[BitMask],
                position.[BaseUnitNo]
            HAVING COUNT_BIG(*) BETWEEN 2 AND @FishSize
        ),
        FishSets AS
        (
            SELECT
                firstBase.[Orientation],
                firstBase.[BitMask],
                firstBase.[BaseUnitNo] AS [Base1],
                secondBase.[BaseUnitNo] AS [Base2],
                CONVERT(tinyint, NULL) AS [Base3],
                CONVERT(tinyint, NULL) AS [Base4],
                CONVERT(smallint, firstBase.[CoverMask] | secondBase.[CoverMask]) AS [CoverMask],
                CONVERT(tinyint, 2) AS [BaseCount]
            FROM BasePatterns AS firstBase
            INNER JOIN BasePatterns AS secondBase
                ON secondBase.[Orientation] = firstBase.[Orientation]
               AND secondBase.[BitMask] = firstBase.[BitMask]
               AND secondBase.[BaseUnitNo] > firstBase.[BaseUnitNo]

            UNION ALL

            SELECT
                firstBase.[Orientation],
                firstBase.[BitMask],
                firstBase.[BaseUnitNo],
                secondBase.[BaseUnitNo],
                thirdBase.[BaseUnitNo],
                NULL,
                CONVERT
                (
                    smallint,
                    firstBase.[CoverMask]
                    | secondBase.[CoverMask]
                    | thirdBase.[CoverMask]
                ),
                3
            FROM BasePatterns AS firstBase
            INNER JOIN BasePatterns AS secondBase
                ON secondBase.[Orientation] = firstBase.[Orientation]
               AND secondBase.[BitMask] = firstBase.[BitMask]
               AND secondBase.[BaseUnitNo] > firstBase.[BaseUnitNo]
            INNER JOIN BasePatterns AS thirdBase
                ON thirdBase.[Orientation] = firstBase.[Orientation]
               AND thirdBase.[BitMask] = firstBase.[BitMask]
               AND thirdBase.[BaseUnitNo] > secondBase.[BaseUnitNo]

            UNION ALL

            SELECT
                firstBase.[Orientation],
                firstBase.[BitMask],
                firstBase.[BaseUnitNo],
                secondBase.[BaseUnitNo],
                thirdBase.[BaseUnitNo],
                fourthBase.[BaseUnitNo],
                CONVERT
                (
                    smallint,
                    firstBase.[CoverMask]
                    | secondBase.[CoverMask]
                    | thirdBase.[CoverMask]
                    | fourthBase.[CoverMask]
                ),
                4
            FROM BasePatterns AS firstBase
            INNER JOIN BasePatterns AS secondBase
                ON secondBase.[Orientation] = firstBase.[Orientation]
               AND secondBase.[BitMask] = firstBase.[BitMask]
               AND secondBase.[BaseUnitNo] > firstBase.[BaseUnitNo]
            INNER JOIN BasePatterns AS thirdBase
                ON thirdBase.[Orientation] = firstBase.[Orientation]
               AND thirdBase.[BitMask] = firstBase.[BitMask]
               AND thirdBase.[BaseUnitNo] > secondBase.[BaseUnitNo]
            INNER JOIN BasePatterns AS fourthBase
                ON fourthBase.[Orientation] = firstBase.[Orientation]
               AND fourthBase.[BitMask] = firstBase.[BitMask]
               AND fourthBase.[BaseUnitNo] > thirdBase.[BaseUnitNo]
        )
        SELECT TOP (1)
            @Orientation = fish.[Orientation],
            @FishDigitMask = fish.[BitMask],
            @Base1 = fish.[Base1],
            @Base2 = fish.[Base2],
            @Base3 = fish.[Base3],
            @Base4 = fish.[Base4],
            @CoverMask = fish.[CoverMask]
        FROM FishSets AS fish
        INNER JOIN dbo.BitCount511 AS bitCount
            ON bitCount.[Mask] = fish.[CoverMask]
           AND bitCount.[BitCount] = @FishSize
        WHERE fish.[BaseCount] = @FishSize
          AND EXISTS
          (
              SELECT 1
              FROM #BoardCells AS target
              INNER JOIN dbo.SudokuDigitMask AS coverUnitMask
                  ON coverUnitMask.[Digit] =
                     CASE fish.[Orientation]
                         WHEN 'R' THEN target.[Col]
                         ELSE target.[Row]
                     END
              WHERE target.[Digit] = '0'
                AND
                (
                    (fish.[Orientation] = 'R'
                     AND target.[Row] NOT IN
                         (
                             fish.[Base1], fish.[Base2],
                             ISNULL(fish.[Base3], 0), ISNULL(fish.[Base4], 0)
                         ))
                    OR
                    (fish.[Orientation] = 'C'
                     AND target.[Col] NOT IN
                         (
                             fish.[Base1], fish.[Base2],
                             ISNULL(fish.[Base3], 0), ISNULL(fish.[Base4], 0)
                         ))
                )
                AND (fish.[CoverMask] & coverUnitMask.[BitMask]) <> 0
                AND (target.[CandidateMask] & fish.[BitMask]) <> 0
          )
        ORDER BY fish.[Orientation], fish.[BitMask], fish.[Base1], fish.[Base2], fish.[Base3], fish.[Base4];

        IF @FishDigitMask IS NOT NULL
        BEGIN
            INSERT INTO #Deduction
            (
                [TechniqueName], [ActionType], [Pos], [Digit],
                [OldCandidateMask], [NewCandidateMask], [RemovedMask], [Evidence]
            )
            SELECT
                CASE @FishSize
                    WHEN 2 THEN 'X-Wing'
                    WHEN 3 THEN 'Swordfish'
                    ELSE 'Jellyfish'
                END,
                'Eliminate',
                target.[Pos],
                NULL,
                target.[CandidateMask],
                CONVERT(smallint, target.[CandidateMask] & ~@FishDigitMask),
                CONVERT(smallint, target.[CandidateMask] & @FishDigitMask),
                N'The selected base units occupy exactly the same number of cover units.'
            FROM #BoardCells AS target
            INNER JOIN dbo.SudokuDigitMask AS coverUnitMask
                ON coverUnitMask.[Digit] =
                   CASE @Orientation
                       WHEN 'R' THEN target.[Col]
                       ELSE target.[Row]
                   END
            WHERE target.[Digit] = '0'
              AND
              (
                  (@Orientation = 'R'
                   AND target.[Row] NOT IN
                       (
                           @Base1, @Base2,
                           ISNULL(@Base3, 0), ISNULL(@Base4, 0)
                       ))
                  OR
                  (@Orientation = 'C'
                   AND target.[Col] NOT IN
                       (
                           @Base1, @Base2,
                           ISNULL(@Base3, 0), ISNULL(@Base4, 0)
                       ))
              )
              AND (@CoverMask & coverUnitMask.[BitMask]) <> 0
              AND (target.[CandidateMask] & @FishDigitMask) <> 0
            ORDER BY target.[Pos];

            GOTO ReturnResult;
        END;

        SET @FishSize += 1;
    END;

ReturnResult:
    SELECT
        [SequenceNo],
        [TechniqueName],
        [ActionType],
        [Pos],
        [Digit],
        [OldCandidateMask],
        [NewCandidateMask],
        [RemovedMask],
        [Evidence]
    FROM #Deduction
    ORDER BY [SequenceNo];
END;
GO
